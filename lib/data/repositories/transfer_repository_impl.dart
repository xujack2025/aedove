import '../../domain/entities/transfer_progress_entity.dart';
import '../../domain/entities/transfer_request_entity.dart';
import '../../domain/entities/transfer_status.dart';
import '../../domain/repositories/transfer_repository.dart';
import '../../services/file_transfer_service.dart' as transfer_service;

class TransferRepositoryImpl implements TransferRepository {
  @override
  Stream<List<TransferRequestEntity>> watchRequests() {
    return transfer_service.FileTransferService.requestsStream.map(
      (requests) => requests
          .map(
            (request) => TransferRequestEntity(
              id: request.id,
              senderId: request.senderId,
              senderName: request.senderName,
              fileName: request.fileName,
              fileSize: request.fileSize,
              fileType: request.fileType,
              timestamp: request.timestamp,
              ipAddress: request.ipAddress,
              targetDeviceIP: request.targetDeviceIP,
              localFilePath: request.localFilePath,
            ),
          )
          .toList(),
    );
  }

  @override
  Stream<TransferProgressEntity> watchProgress() {
    return transfer_service.FileTransferService.progressStream.map(
      (progress) => TransferProgressEntity(
        requestId: progress.requestId,
        fileName: progress.fileName,
        totalBytes: progress.totalBytes,
        transferredBytes: progress.transferredBytes,
        status: _mapStatus(progress.status),
        startTime: progress.startTime,
        errorMessage: progress.errorMessage,
      ),
    );
  }

  @override
  Stream<String> watchFileSaved() {
    return transfer_service.FileTransferService.fileSavedStream;
  }

  @override
  Future<void> acceptTransfer(String requestId) {
    return transfer_service.FileTransferService.acceptFileTransfer(requestId);
  }

  @override
  Future<void> denyTransfer(String requestId) {
    return transfer_service.FileTransferService.denyFileTransfer(requestId);
  }

  TransferStatus _mapStatus(dynamic status) {
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
