import '../../domain/entities/settings_entity.dart';

class SettingsModel {
  const SettingsModel({
    required this.deviceName,
    required this.deviceId,
    required this.notificationsEnabled,
  });

  final String deviceName;
  final String deviceId;
  final bool notificationsEnabled;

  SettingsEntity toEntity() {
    return SettingsEntity(
      deviceName: deviceName,
      deviceId: deviceId,
      notificationsEnabled: notificationsEnabled,
    );
  }
}
