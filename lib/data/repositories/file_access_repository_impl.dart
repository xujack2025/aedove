import '../../domain/repositories/file_access_repository.dart';
import '../datasources/file_access/file_access_data_source.dart';

class FileAccessRepositoryImpl implements FileAccessRepository {
  const FileAccessRepositoryImpl(this._dataSource);

  final FileAccessDataSource _dataSource;

  @override
  Future<bool> openFile(String filePath) {
    return _dataSource.openFile(filePath);
  }

  @override
  Future<bool> showInFileManager(String filePath) {
    return _dataSource.showInFileManager(filePath);
  }
}
