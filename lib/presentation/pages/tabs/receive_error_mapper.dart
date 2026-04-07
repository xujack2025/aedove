class ReceiveErrorMapper {
  const ReceiveErrorMapper._();

  static const String gallerySavedHint =
      'File saved to gallery. Open your Photos/Gallery app to view.';

  static String savedToGalleryMessage(String fileName) {
    return '$fileName saved to gallery. Open your Photos/Gallery app to view.';
  }

  static String openFileManagerFailure() {
    return 'Could not open file manager.';
  }

  static String openFileFailure() {
    return 'Could not open file.';
  }

  static String openFileError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('denied')) {
      return 'Permission denied. Please allow file access and try again.';
    }

    return 'Error opening file. Please try again.';
  }
}
