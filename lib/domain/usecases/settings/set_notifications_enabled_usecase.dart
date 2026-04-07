import '../../repositories/settings_repository.dart';

class SetNotificationsEnabledUsecase {
  const SetNotificationsEnabledUsecase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(bool enabled) {
    return _repository.setNotificationsEnabled(enabled);
  }
}
