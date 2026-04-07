import '../../models/device_model.dart';
import '../../../services/device_discovery_service.dart';

class DeviceDiscoveryDataSource {
  const DeviceDiscoveryDataSource();

  Future<void> start() => DeviceDiscoveryService.start();

  Future<void> stop() => DeviceDiscoveryService.stop();

  Stream<List<DeviceModel>> watchDevices() {
    return DeviceDiscoveryService.devicesStream.map(
      (devices) => devices.map(DeviceModel.fromService).toList(),
    );
  }
}
