import '../../repositories/transfer_repository.dart';

class AcceptTransferUsecase {
  final TransferRepository repository;

  AcceptTransferUsecase(this.repository);

  Future<void> call(String requestId) {
    return repository.acceptTransfer(requestId);
  }
}
