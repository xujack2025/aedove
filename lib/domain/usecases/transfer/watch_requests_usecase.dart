import '../../repositories/transfer_repository.dart';
import '../../entities/transfer_request_entity.dart';

class WatchRequestsUsecase {
  final TransferRepository repository;

  WatchRequestsUsecase(this.repository);

  Stream<List<TransferRequestEntity>> call() {
    return repository.watchRequests();
  }
}
