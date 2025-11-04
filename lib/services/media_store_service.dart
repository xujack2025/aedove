import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mime/mime.dart';
import 'package:gal/gal.dart';

class MediaStoreService {
  /// Determine if file is media (image or video)
  static bool isMediaFile(String fileName) {
    final mimeType = lookupMimeType(fileName);
    return mimeType?.startsWith('image/') == true ||
        mimeType?.startsWith('video/') == true;
  }

  /// Save a file using the appropriate method for the platform and Android version.
  /// Returns the path where the file was saved.
  static Future<String> saveFile(String fileName, List<int> bytes) async {
    if (isMediaFile(fileName)) {
      try {
        final result = await saveToGallery(fileName, bytes);
        if (result != null) {
          return result;
        }
      } catch (e) {
        print('Failed to save to gallery, falling back to regular storage: $e');
      }
    }

    if (Platform.isAndroid) {
      return _saveAndroidFile(fileName, bytes);
    } else if (Platform.isMacOS) {
      return _saveMacOSFile(fileName, bytes);
    } else {
      return _saveIOSFile(fileName, bytes);
    }
  }

  /// Save media file to device's gallery
  static Future<String?> saveToGallery(String fileName, List<int> bytes) async {
    try {
      // Only attempt gallery operations on supported platforms
      if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        return null;
      }

      final mimeType = lookupMimeType(fileName);
      final isImage = mimeType?.startsWith('image/') == true;
      final isVideo = mimeType?.startsWith('video/') == true;

      if (!isImage && !isVideo) {
        return null;
      }

      // First save to temporary file
      final tempDir = await getTemporaryDirectory();
      final safeName = fileName.replaceAll(RegExp(r"[^A-Za-z0-9._-]"), "_");
      final tempFile = File('${tempDir.path}/$safeName');
      await tempFile.writeAsBytes(bytes);

      // Save to gallery
      if (isImage) {
        await Gal.putImage(tempFile.path);
      } else {
        await Gal.putVideo(tempFile.path);
      }

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return 'Saved to gallery: $fileName';
    } catch (e) {
      print('Error saving to gallery: $e');
      return null;
    }
  }

  /// Save file in iOS app Documents directory
  static Future<String> _saveIOSFile(String fileName, List<int> bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = path.join(directory.path, fileName);
    final file = File(filePath);

    try {
      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      print('Error saving file on iOS: $e');
      throw Exception('Failed to save file: $e');
    }
  }

  /// Save file in macOS Downloads directory
  static Future<String> _saveMacOSFile(String fileName, List<int> bytes) async {
    final directory = await getDownloadsDirectory();
    if (directory == null) {
      throw Exception('Failed to access Downloads directory');
    }

    final filePath = path.join(directory.path, fileName);
    final file = File(filePath);

    try {
      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      print('Error saving file on macOS: $e');
      throw Exception('Failed to save file: $e');
    }
  }

  /// Save file on Android using the most appropriate method for the Android version
  static Future<String> _saveAndroidFile(
    String fileName,
    List<int> bytes,
  ) async {
    // First check storage permission
    if (!await _checkStoragePermission()) {
      throw Exception('Storage permission denied');
    }

    // Try to use platform MediaStore (via MethodChannel) to save into Downloads
    const channel = MethodChannel('drop.media_store');
    try {
      final result = await channel.invokeMethod<String>('saveFileToDownloads', {
        'fileName': fileName,
        'bytes': bytes,
      });
      if (result != null && result.isNotEmpty) {
        print('File saved via MediaStore: $result');
        return result;
      }
    } catch (e) {
      print('MediaStore save failed or not available: $e');
    }

    // Fallback: try writing directly to Downloads
    try {
      // Try to get the platform-specific Downloads directory instead of hardcoding
      List<Directory>? externalDownloads = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );

      Directory downloadDir;
      if (externalDownloads != null && externalDownloads.isNotEmpty) {
        downloadDir = externalDownloads.first;
      } else {
        // Fallback: try app external storage root and derive Download folder if possible
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          // Many devices place public storage at the path before "Android"
          final parts = extDir.path.split(Platform.pathSeparator);
          final androidIndex = parts.indexWhere(
            (p) => p.toLowerCase() == 'android',
          );
          String rootPath;
          if (androidIndex > 0) {
            rootPath = parts
                .sublist(0, androidIndex)
                .join(Platform.pathSeparator);
          } else {
            rootPath = extDir.path;
          }
          downloadDir = Directory(path.join(rootPath, 'Download'));
        } else {
          // Last resort: common Android download path
          downloadDir = Directory('/storage/emulated/0/Download');
        }
      }

      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final filePath = path.join(downloadDir.path, fileName);
      String uniqueFilePath = await _getUniqueFilePath(filePath);
      final uniqueFile = File(uniqueFilePath);
      try {
        await uniqueFile.writeAsBytes(bytes);
        print('File saved successfully to: $uniqueFilePath');
        return uniqueFilePath;
      } catch (e) {
        print('Error writing to Downloads: $e');
        return await _saveToAppStorage(fileName, bytes);
      }
    } catch (e) {
      print('Error accessing Downloads directory: $e');
      return await _saveToAppStorage(fileName, bytes);
    }
  }

  /// Save file to app-specific storage when external storage is not available
  static Future<String> _saveToAppStorage(
    String fileName,
    List<int> bytes,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = path.join(directory.path, fileName);
    String uniqueFilePath = await _getUniqueFilePath(filePath);
    final file = File(uniqueFilePath);

    try {
      await file.writeAsBytes(bytes);
      print('File saved to app storage at: $uniqueFilePath');
      return uniqueFilePath;
    } catch (e) {
      print('Error saving to app storage: $e');
      throw Exception('Failed to save file: $e');
    }
  }

  /// Check and request storage permission if needed
  static Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status.isDenied) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
      return status.isGranted;
    }
    return true;
  }

  /// Get a unique file path by appending a number if file exists
  static Future<String> _getUniqueFilePath(String originalPath) async {
    String directory = path.dirname(originalPath);
    String fileName = path.basenameWithoutExtension(originalPath);
    String extension = path.extension(originalPath);
    String filePath = originalPath;
    int counter = 1;

    while (await File(filePath).exists()) {
      filePath = path.join(directory, '${fileName}_$counter$extension');
      counter++;
    }

    return filePath;
  }
}
