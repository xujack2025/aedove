import '../../repositories/device_repository.dart';

class StopDiscoveryUsecase {
  final DeviceRepository repository;

  StopDiscoveryUsecase(this.repository);

  Future<void> call() async {
    await repository.stopDiscovery();
  }
}
