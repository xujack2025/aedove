import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/settings/load_settings_usecase.dart';
import '../../../domain/usecases/settings/save_device_name_usecase.dart';
import '../../../domain/usecases/settings/set_notifications_enabled_usecase.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({
    required LoadSettingsUsecase loadSettingsUsecase,
    required SaveDeviceNameUsecase saveDeviceNameUsecase,
    required SetNotificationsEnabledUsecase setNotificationsEnabledUsecase,
  }) : _loadSettingsUsecase = loadSettingsUsecase,
       _saveDeviceNameUsecase = saveDeviceNameUsecase,
       _setNotificationsEnabledUsecase = setNotificationsEnabledUsecase,
       super(const SettingsState()) {
    on<SettingsLoaded>(_onLoaded);
    on<SettingsDeviceNameChanged>(_onDeviceNameChanged);
    on<SettingsNotificationsToggled>(_onNotificationsToggled);
  }

  final LoadSettingsUsecase _loadSettingsUsecase;
  final SaveDeviceNameUsecase _saveDeviceNameUsecase;
  final SetNotificationsEnabledUsecase _setNotificationsEnabledUsecase;

  Future<void> _onLoaded(
    SettingsLoaded event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final settings = await _loadSettingsUsecase();
      emit(
        state.copyWith(
          isLoading: false,
          deviceName: settings.deviceName,
          deviceId: settings.deviceId,
          notificationsEnabled: settings.notificationsEnabled,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onDeviceNameChanged(
    SettingsDeviceNameChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final trimmed = event.deviceName.trim();
    if (trimmed.isEmpty) {
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _saveDeviceNameUsecase(trimmed);
      emit(
        state.copyWith(isLoading: false, deviceName: trimmed, clearError: true),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onNotificationsToggled(
    SettingsNotificationsToggled event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _setNotificationsEnabledUsecase(event.enabled);
      emit(
        state.copyWith(
          isLoading: false,
          notificationsEnabled: event.enabled,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }
}
