import '../entities/transfer_progress_entity.dart';
import '../entities/transfer_request_entity.dart';

abstract class TransferRepository {
  Future<void> sendFile({
    required String targetDeviceId,
    required String targetDeviceIP,
    required String filePath,
    required String fileName,
    required int targetDevicePort,
  });

  Stream<List<TransferRequestEntity>> watchRequests();

  Stream<TransferProgressEntity> watchProgress();

  Stream<String> watchFileSaved();

  Future<void> acceptTransfer(String requestId);

  Future<void> denyTransfer(String requestId);
}
