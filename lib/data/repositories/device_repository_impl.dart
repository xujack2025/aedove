import 'package:aedove/domain/entities/device_type.dart';
import '../datasources/device/device_discovery_data_source.dart';
import '../../domain/entities/device_entity.dart';
import '../../domain/repositories/device_repository.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  const DeviceRepositoryImpl(this._dataSource);

  final DeviceDiscoveryDataSource _dataSource;

  @override
  Future<void> startDiscovery() async {
    await _dataSource.start();
  }

  @override
  Future<void> stopDiscovery() async {
    await _dataSource.stop();
  }

  @override
  Stream<List<DeviceEntity>> watchDevices() {
    return _dataSource.watchDevices().map(
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
