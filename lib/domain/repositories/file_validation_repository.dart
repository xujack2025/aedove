import '../entities/file_validation_result_entity.dart';

abstract class FileValidationRepository {
  Future<FileValidationResultEntity> validatePaths({
    required List<String> paths,
    required bool mediaOnly,
  });
}
