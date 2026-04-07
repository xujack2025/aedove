import '../entities/device_entity.dart';

abstract class DeviceRepository {
  Future<void> startDiscovery();

  Future<void> stopDiscovery();

  Stream<List<DeviceEntity>> watchDevices();
}
