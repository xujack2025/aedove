import '../../repositories/file_access_repository.dart';

class OpenFileUsecase {
  const OpenFileUsecase(this._repository);

  final FileAccessRepository _repository;

  Future<bool> call(String filePath) {
    return _repository.openFile(filePath);
  }
}
