import '../../entities/file_validation_result_entity.dart';
import '../../repositories/file_validation_repository.dart';

class ValidateSelectedFilesUsecase {
  const ValidateSelectedFilesUsecase(this._repository);

  final FileValidationRepository _repository;

  Future<FileValidationResultEntity> call({
    required List<String> paths,
    required bool mediaOnly,
  }) {
    return _repository.validatePaths(paths: paths, mediaOnly: mediaOnly);
  }
}
