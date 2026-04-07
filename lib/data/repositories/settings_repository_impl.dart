import '../../domain/entities/settings_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings/settings_local_data_source.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._dataSource);

  final SettingsLocalDataSource _dataSource;

  @override
  Future<SettingsEntity> loadSettings() async {
    return (await _dataSource.loadSettings()).toEntity();
  }

  @override
  Future<void> saveDeviceName(String deviceName) async {
    await _dataSource.saveDeviceName(deviceName);
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _dataSource.setNotificationsEnabled(enabled);
  }
}
