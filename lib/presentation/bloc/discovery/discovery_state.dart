import 'package:aedove/domain/entities/device_entity.dart';
import 'package:equatable/equatable.dart';

sealed class DiscoveryState extends Equatable {
  final List<DeviceEntity> devices;
  const DiscoveryState({required this.devices});

  @override
  List<Object?> get props => [devices];
}

class DiscoveryInitial extends DiscoveryState {
  const DiscoveryInitial() : super(devices: const []);
}

class DiscoveryLoading extends DiscoveryState {
  const DiscoveryLoading({required super.devices});
}

class DiscoveryLoaded extends DiscoveryState {
  const DiscoveryLoaded({required super.devices});
}

class DiscoveryError extends DiscoveryState {
  final String message;
  const DiscoveryError({required this.message, required super.devices});

  @override
  List<Object?> get props => [message, devices];
}
