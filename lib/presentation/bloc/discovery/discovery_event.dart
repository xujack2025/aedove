import 'package:aedove/domain/entities/device_entity.dart';
import 'package:equatable/equatable.dart';

sealed class DiscoveryEvent extends Equatable {
  const DiscoveryEvent();

  @override
  List<Object?> get props => [];
}

class DiscoveryStarted extends DiscoveryEvent {
  const DiscoveryStarted();
}

class DiscoveryStopped extends DiscoveryEvent {
  const DiscoveryStopped();
}

class DevicesUpdated extends DiscoveryEvent {
  final List<DeviceEntity> devices;
  const DevicesUpdated(this.devices);

  @override
  List<Object?> get props => [devices];
}
