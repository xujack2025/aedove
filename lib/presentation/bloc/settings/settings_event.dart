import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class SettingsLoaded extends SettingsEvent {
  const SettingsLoaded();
}

class SettingsDeviceNameChanged extends SettingsEvent {
  const SettingsDeviceNameChanged(this.deviceName);

  final String deviceName;

  @override
  List<Object?> get props => [deviceName];
}

class SettingsNotificationsToggled extends SettingsEvent {
  const SettingsNotificationsToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}
