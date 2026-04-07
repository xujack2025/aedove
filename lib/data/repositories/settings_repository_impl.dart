import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/settings_entity.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl();

  @override
  Future<SettingsEntity> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsEntity(
      deviceName: prefs.getString('device_name') ?? 'My Device',
      deviceId: prefs.getString('device_id') ?? 'Unknown',
      notificationsEnabled: prefs.getBool('notifications_enabled') ?? true,
    );
  }

  @override
  Future<void> saveDeviceName(String deviceName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name', deviceName);
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
  }
}
