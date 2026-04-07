import '../../domain/entities/device_entity.dart';
import '../../domain/entities/device_type.dart';

class DeviceModel {
  const DeviceModel({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.lastSeen,
    required this.isOnline,
  });

  final String id;
  final String name;
  final String ip;
  final int port;
  final DateTime lastSeen;
  final bool isOnline;

  factory DeviceModel.fromService(dynamic device) {
    return DeviceModel(
      id: device.id as String,
      name: device.name as String,
      ip: device.ip as String,
      port: device.port as int,
      lastSeen: device.lastSeen as DateTime,
      isOnline: device.isOnline as bool? ?? true,
    );
  }

  DeviceEntity toEntity() {
    return DeviceEntity(
      id: id,
      name: name,
      ip: ip,
      port: port,
      type: DeviceType.unknown,
    );
  }
}
