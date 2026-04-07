import 'package:file_picker/file_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class SendPickerHelper {
  const SendPickerHelper._();

  static const String filesValidationMessage = 'Validating files...';
  static const String mediaValidationMessage = 'Validating media files...';
  static const String filesAllRejectedMessage =
      'All selected files were unavailable. Please try different files.';
  static const String mediaAllRejectedMessage =
      'All selected files were unsupported. Please select image or video files.';

  static List<String> platformFilePaths(Iterable<PlatformFile> files) {
    return files
        .map((file) => file.path)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toList();
  }

  static Future<List<String>> assetPaths(
    List<AssetEntity> assets, {
    required void Function(String message) onProgress,
  }) async {
    final paths = <String>[];

    for (var index = 0; index < assets.length; index++) {
      onProgress(processingMessage(index, assets.length));
      final file = await assets[index].file;
      if (file != null) {
        paths.add(file.path);
      }
    }

    return paths;
  }

  static String processingMessage(int index, int total) {
    return 'Processing file ${index + 1}/$total...';
  }

  static String validationMessage(bool mediaOnly) {
    return mediaOnly ? mediaValidationMessage : filesValidationMessage;
  }

  static String allRejectedMessage(bool mediaOnly) {
    return mediaOnly ? mediaAllRejectedMessage : filesAllRejectedMessage;
  }
}
