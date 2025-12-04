import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mime/mime.dart';
import 'package:gal/gal.dart';
import 'package:open_file/open_file.dart';

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
        debugPrint(
          'Failed to save to gallery, falling back to regular storage: $e',
        );
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
      if (!(Platform.isAndroid || Platform.isIOS)) {
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

      // Return a special marker to indicate gallery save
      return 'gallery://$fileName';
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
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
      debugPrint('Error saving file on iOS: $e');
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
      debugPrint('Error saving file on macOS: $e');
      throw Exception('Failed to save file: $e');
    }
  }

  /// Save file on Android using the most appropriate method for the Android version
  static Future<String> _saveAndroidFile(
    String fileName,
    List<int> bytes,
  ) async {
    // Check storage permission (will return true even if limited to allow app-specific storage)
    await _checkStoragePermission();

    // Android 10+ (API 29+): Use scoped storage
    // Save to app-specific external storage which doesn't require special permissions
    try {
      // Get app-specific external storage directory for downloads
      // This is accessible without MANAGE_EXTERNAL_STORAGE and survives app uninstall
      final List<Directory>? appDownloadDirs =
          await getExternalStorageDirectories(type: StorageDirectory.downloads);

      if (appDownloadDirs != null && appDownloadDirs.isNotEmpty) {
        final downloadDir = appDownloadDirs.first;

        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }

        final filePath = path.join(downloadDir.path, fileName);
        String uniqueFilePath = await _getUniqueFilePath(filePath);
        final uniqueFile = File(uniqueFilePath);

        await uniqueFile.writeAsBytes(bytes);

        // Scan the file to make it visible in file managers
        await _scanMediaFile(uniqueFilePath);

        debugPrint(
          'File saved successfully to app-specific storage: $uniqueFilePath',
        );
        return uniqueFilePath;
      }
    } catch (e) {
      debugPrint('Error saving to app-specific external storage: $e');
    }

    // Fallback: save to app internal storage (always works, no permission needed)
    return await _saveToAppStorage(fileName, bytes);
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
      debugPrint('File saved to app storage at: $uniqueFilePath');
      return uniqueFilePath;
    } catch (e) {
      debugPrint('Error saving to app storage: $e');
      throw Exception('Failed to save file: $e');
    }
  }

  /// Check and request storage permission if needed
  static Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      // Try media permissions first (Android 13+)
      try {
        final photosStatus = await Permission.photos.status;
        final videosStatus = await Permission.videos.status;

        if (photosStatus.isGranted ||
            photosStatus.isLimited ||
            videosStatus.isGranted ||
            videosStatus.isLimited) {
          return true;
        }
      } catch (e) {
        debugPrint('Media permissions not available: $e');
      }

      // Try legacy storage permission (Android 10-12)
      try {
        final status = await Permission.storage.status;
        if (status.isDenied) {
          final result = await Permission.storage.request();
          return result.isGranted || result.isLimited;
        }
        return status.isGranted || status.isLimited;
      } catch (e) {
        debugPrint('Storage permission check failed: $e');
      }
    }
    // Return true to allow fallback to app-specific storage
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

  /// Open a file with the default application
  /// Returns true if successful, false otherwise
  static Future<bool> openFile(String filePath) async {
    try {
      // Handle gallery marker
      if (filePath.startsWith('gallery://')) {
        debugPrint('File is in gallery, cannot open directly');
        return false;
      }

      final result = await OpenFile.open(filePath);
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('Error opening file: $e');
      return false;
    }
  }

  /// Open file manager at the location of the file
  /// On Android, this will trigger MediaScanner to make the file visible
  static Future<bool> showInFileManager(String filePath) async {
    try {
      // Handle gallery marker
      if (filePath.startsWith('gallery://')) {
        debugPrint('File is in gallery, use gallery app to view');
        return false;
      }

      if (Platform.isAndroid) {
        // Scan the file to make it visible in file managers
        await _scanMediaFile(filePath);

        // Try to open the parent directory
        final directory = path.dirname(filePath);
        final result = await OpenFile.open(directory);
        return result.type == ResultType.done;
      } else if (Platform.isMacOS) {
        // On macOS, open Finder at the file location
        final directory = path.dirname(filePath);
        final result = await OpenFile.open(directory);
        return result.type == ResultType.done;
      } else if (Platform.isIOS) {
        // iOS doesn't have a file manager concept, just open the file
        return await openFile(filePath);
      }

      return false;
    } catch (e) {
      debugPrint('Error showing file in manager: $e');
      return false;
    }
  }

  /// Scan media file to make it visible in Android file managers and galleries
  static Future<void> _scanMediaFile(String filePath) async {
    if (!Platform.isAndroid) return;

    try {
      const platform = MethodChannel('aedove/media_store');
      await platform.invokeMethod('scanFile', {'path': filePath});
      debugPrint('Media scan triggered for: $filePath');
    } catch (e) {
      debugPrint('Error scanning media file: $e');
    }
  }
}
