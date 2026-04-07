import '../../domain/repositories/file_access_repository.dart';
import '../../services/media_store_service.dart';

class FileAccessRepositoryImpl implements FileAccessRepository {
  const FileAccessRepositoryImpl();

  @override
  Future<bool> openFile(String filePath) {
    return MediaStoreService.openFile(filePath);
  }

  @override
  Future<bool> showInFileManager(String filePath) {
    return MediaStoreService.showInFileManager(filePath);
  }
}
