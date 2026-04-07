import '../../repositories/transfer_repository.dart';

class WatchFileSavedUsecase {
  final TransferRepository repository;

  WatchFileSavedUsecase(this.repository);

  Stream<String> call() {
    return repository.watchFileSaved();
  }
}
