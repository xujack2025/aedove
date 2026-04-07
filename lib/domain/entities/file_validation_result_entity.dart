import 'validated_file_entity.dart';

class FileValidationResultEntity {
  const FileValidationResultEntity({
    required this.files,
    required this.rejectedCount,
  });

  final List<ValidatedFileEntity> files;
  final int rejectedCount;
}
