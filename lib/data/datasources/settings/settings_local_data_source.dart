import 'package:shared_preferences/shared_preferences.dart';

import '../../models/settings_model.dart';

class SettingsLocalDataSource {
  const SettingsLocalDataSource();

  Future<SettingsModel> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsModel(
      deviceName: prefs.getString('device_name') ?? 'My Device',
      deviceId: prefs.getString('device_id') ?? 'Unknown',
      notificationsEnabled: prefs.getBool('notifications_enabled') ?? true,
    );
  }

  Future<void> saveDeviceName(String deviceName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name', deviceName);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
  }
}
