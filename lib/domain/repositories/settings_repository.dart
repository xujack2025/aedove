import '../entities/settings_entity.dart';

abstract class SettingsRepository {
  Future<SettingsEntity> loadSettings();
  Future<void> saveDeviceName(String deviceName);
  Future<void> setNotificationsEnabled(bool enabled);
}
