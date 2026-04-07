import '../../entities/device_entity.dart';
import '../../repositories/device_repository.dart';

class WatchDevicesUsecase {
  final DeviceRepository repository;

  WatchDevicesUsecase(this.repository);

  Stream<List<DeviceEntity>> call() {
    return repository.watchDevices();
  }
}
