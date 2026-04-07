abstract class FileAccessRepository {
  Future<bool> openFile(String filePath);
  Future<bool> showInFileManager(String filePath);
}
