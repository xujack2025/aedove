import '../../repositories/device_repository.dart';

class StartDiscoveryUsecase {
  final DeviceRepository repository;

  StartDiscoveryUsecase(this.repository);

  Future<void> call() async {
    await repository.startDiscovery();
  }
}
