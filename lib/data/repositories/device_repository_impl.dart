import 'package:aedove/domain/entities/device_type.dart';
import 'package:aedove/services/device_discovery_service.dart';

import '../../domain/entities/device_entity.dart';
import '../../domain/repositories/device_repository.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  @override
  Future<void> startDiscovery() async {
    await DeviceDiscoveryService.start();
  }

  @override
  Future<void> stopDiscovery() async {
    await DeviceDiscoveryService.stop();
  }

  @override
  Stream<List<DeviceEntity>> watchDevices() {
    return DeviceDiscoveryService.devicesStream.map(
      (devices) => devices
          .map(
            (device) => DeviceEntity(
              id: device.id,
              name: device.name,
              ip: device.ip,
              port: device.port,
              type: DeviceType.unknown,
            ),
          )
          .toList(),
    );
  }
}
