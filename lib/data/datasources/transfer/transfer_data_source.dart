import '../../models/transfer_progress_model.dart';
import '../../models/transfer_request_model.dart';
import '../../../services/file_transfer_service.dart' as transfer_service;

class TransferDataSource {
  const TransferDataSource();

  Future<void> sendFile({
    required String targetDeviceId,
    required String targetDeviceIP,
    required String filePath,
    required String fileName,
    required int targetDevicePort,
  }) {
    return transfer_service.FileTransferService.sendFile(
      targetDeviceId: targetDeviceId,
      targetDeviceIP: targetDeviceIP,
      filePath: filePath,
      fileName: fileName,
      targetDevicePort: targetDevicePort,
    );
  }

  Stream<List<TransferRequestModel>> watchRequests() {
    return transfer_service.FileTransferService.requestsStream.map(
      (requests) => requests.map(TransferRequestModel.fromService).toList(),
    );
  }

  Stream<TransferProgressModel> watchProgress() {
    return transfer_service.FileTransferService.progressStream.map(
      TransferProgressModel.fromService,
    );
  }

  Stream<String> watchFileSaved() {
    return transfer_service.FileTransferService.fileSavedStream;
  }

  Future<void> acceptTransfer(String requestId) {
    return transfer_service.FileTransferService.acceptFileTransfer(requestId);
  }

  Future<void> denyTransfer(String requestId) {
    return transfer_service.FileTransferService.denyFileTransfer(requestId);
  }
}
