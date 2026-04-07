import '../../../services/media_store_service.dart';

class FileAccessDataSource {
  const FileAccessDataSource();

  Future<bool> openFile(String filePath) {
    return MediaStoreService.openFile(filePath);
  }

  Future<bool> showInFileManager(String filePath) {
    return MediaStoreService.showInFileManager(filePath);
  }
}
