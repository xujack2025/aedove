import '../../domain/entities/transfer_progress_entity.dart';
import '../../domain/entities/transfer_status.dart';

class TransferProgressModel {
  const TransferProgressModel({
    required this.requestId,
    required this.fileName,
    required this.totalBytes,
    required this.transferredBytes,
    required this.status,
    required this.startTime,
    required this.errorMessage,
  });

  final String requestId;
  final String fileName;
  final int totalBytes;
  final int transferredBytes;
  final TransferStatus status;
  final DateTime startTime;
  final String? errorMessage;

  factory TransferProgressModel.fromService(dynamic progress) {
    return TransferProgressModel(
      requestId: progress.requestId as String,
      fileName: progress.fileName as String,
      totalBytes: progress.totalBytes as int,
      transferredBytes: progress.transferredBytes as int,
      status: _mapStatus(progress.status),
      startTime: progress.startTime as DateTime,
      errorMessage: progress.errorMessage as String?,
    );
  }

  TransferProgressEntity toEntity() {
    return TransferProgressEntity(
      requestId: requestId,
      fileName: fileName,
      totalBytes: totalBytes,
      transferredBytes: transferredBytes,
      status: status,
      startTime: startTime,
      errorMessage: errorMessage,
    );
  }

  static TransferStatus _mapStatus(dynamic status) {
    switch (status.toString()) {
      case 'TransferStatus.pending':
        return TransferStatus.pending;
      case 'TransferStatus.transferring':
        return TransferStatus.transferring;
      case 'TransferStatus.completed':
        return TransferStatus.completed;
      case 'TransferStatus.failed':
        return TransferStatus.failed;
      default:
        return TransferStatus.pending;
    }
  }
}
