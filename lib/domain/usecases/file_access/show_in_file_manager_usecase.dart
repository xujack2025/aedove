import '../../repositories/file_access_repository.dart';

class ShowInFileManagerUsecase {
  const ShowInFileManagerUsecase(this._repository);

  final FileAccessRepository _repository;

  Future<bool> call(String filePath) {
    return _repository.showInFileManager(filePath);
  }
}
