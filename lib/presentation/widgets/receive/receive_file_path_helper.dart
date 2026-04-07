class ReceiveFilePathHelper {
  const ReceiveFilePathHelper._();

  static bool isGalleryPath(String filePath) {
    return filePath.startsWith('content://') ||
        filePath.contains('DCIM') ||
        filePath.contains('Pictures') ||
        filePath.contains('Movies');
  }

  static bool isExplicitGallerySavedPath(String filePath) {
    return filePath.startsWith('gallery://');
  }

  static String gallerySavedFileName(String filePath) {
    return filePath.replaceFirst('gallery://', '');
  }

  static String gallerySavedMessage(String fileName) {
    return '$fileName saved to gallery. Open your Photos/Gallery app to view.';
  }

  static String gallerySavedHint() {
    return 'File saved to gallery. Open your Photos/Gallery app to view.';
  }

  static String shortPath(String fullPath) {
    final parts = fullPath.split('/');
    if (parts.length <= 5) {
      return fullPath;
    }
    return parts.sublist(parts.length - 5).join('/');
  }
}
