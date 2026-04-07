import '../../repositories/transfer_repository.dart';

class DenyTransferUsecase {
  final TransferRepository repository;

  DenyTransferUsecase(this.repository);

  Future<void> call(String requestId) {
    return repository.denyTransfer(requestId);
  }
}
