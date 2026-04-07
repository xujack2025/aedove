import '../../repositories/settings_repository.dart';

class SaveDeviceNameUsecase {
  const SaveDeviceNameUsecase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(String deviceName) {
    return _repository.saveDeviceName(deviceName);
  }
}
