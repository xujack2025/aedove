import 'dart:io';

import 'package:mime/mime.dart';

import '../../domain/entities/file_validation_result_entity.dart';
import '../../domain/entities/validated_file_entity.dart';
import '../../domain/repositories/file_validation_repository.dart';

class FileValidationRepositoryImpl implements FileValidationRepository {
  const FileValidationRepositoryImpl();

  @override
  Future<FileValidationResultEntity> validatePaths({
    required List<String> paths,
    required bool mediaOnly,
  }) async {
    final validFiles = <ValidatedFileEntity>[];
    int rejectedCount = 0;

    for (final path in paths) {
      if (path.isEmpty) {
        rejectedCount++;
        continue;
      }

      try {
        final file = File(path);
        final stat = await FileStat.stat(path);
        if (stat.type != FileSystemEntityType.file || !await file.exists()) {
          rejectedCount++;
          continue;
        }

        final length = await file.length();
        if (length <= 0) {
          rejectedCount++;
          continue;
        }

        if (mediaOnly) {
          final mimeType = lookupMimeType(path);
          final isMedia =
              mimeType != null &&
              (mimeType.startsWith('image/') || mimeType.startsWith('video/'));
          if (!isMedia) {
            rejectedCount++;
            continue;
          }
        }

        validFiles.add(ValidatedFileEntity(path: path));
      } catch (_) {
        rejectedCount++;
      }
    }

    return FileValidationResultEntity(
      files: validFiles,
      rejectedCount: rejectedCount,
    );
  }
}
