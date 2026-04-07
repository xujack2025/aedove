import '../entities/transfer_progress_entity.dart';
import '../entities/transfer_request_entity.dart';

abstract class TransferRepository {
  Stream<List<TransferRequestEntity>> watchRequests();

  Stream<TransferProgressEntity> watchProgress();

  Stream<String> watchFileSaved();

  Future<void> acceptTransfer(String requestId);

  Future<void> denyTransfer(String requestId);
}
