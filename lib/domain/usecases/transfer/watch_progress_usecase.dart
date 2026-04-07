import '../../repositories/transfer_repository.dart';
import '../../entities/transfer_progress_entity.dart';

class WatchProgressUsecase {
  final TransferRepository repository;

  WatchProgressUsecase(this.repository);

  Stream<TransferProgressEntity> call() {
    return repository.watchProgress();
  }
}
