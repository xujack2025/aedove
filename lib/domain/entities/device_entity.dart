import 'package:equatable/equatable.dart';

import 'device_type.dart';

class DeviceEntity extends Equatable {
  final String id;
  final String name;
  final String ip;
  final int port;
  final DeviceType type;

  const DeviceEntity({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.type,
  });

  @override
  List<Object?> get props => [id, name, ip, port, type];
}
