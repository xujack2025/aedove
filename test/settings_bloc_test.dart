import 'package:aedove/domain/entities/settings_entity.dart';
import 'package:aedove/domain/repositories/settings_repository.dart';
import 'package:aedove/domain/usecases/settings/load_settings_usecase.dart';
import 'package:aedove/domain/usecases/settings/save_device_name_usecase.dart';
import 'package:aedove/domain/usecases/settings/set_notifications_enabled_usecase.dart';
import 'package:aedove/presentation/bloc/settings/settings_bloc.dart';
import 'package:aedove/presentation/bloc/settings/settings_event.dart';
import 'package:aedove/presentation/bloc/settings/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettingsRepository implements SettingsRepository {
  SettingsEntity _entity = const SettingsEntity(
    deviceName: 'My Device',
    deviceId: 'device-1',
    notificationsEnabled: true,
  );

  @override
  Future<SettingsEntity> loadSettings() async => _entity;

  @override
  Future<void> saveDeviceName(String deviceName) async {
    _entity = _entity.copyWith(deviceName: deviceName);
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    _entity = _entity.copyWith(notificationsEnabled: enabled);
  }
}

void main() {
  group('SettingsBloc', () {
    test('loads settings and emits populated state', () async {
      final repo = _FakeSettingsRepository();
      final bloc = SettingsBloc(
        loadSettingsUsecase: LoadSettingsUsecase(repo),
        saveDeviceNameUsecase: SaveDeviceNameUsecase(repo),
        setNotificationsEnabledUsecase: SetNotificationsEnabledUsecase(repo),
      );

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          const SettingsState(isLoading: true),
          const SettingsState(
            isLoading: false,
            deviceName: 'My Device',
            deviceId: 'device-1',
            notificationsEnabled: true,
          ),
        ]),
      );

      bloc.add(const SettingsLoaded());
      await expectation;
      await bloc.close();
    });

    test('updates device name and notification setting', () async {
      final repo = _FakeSettingsRepository();
      final bloc = SettingsBloc(
        loadSettingsUsecase: LoadSettingsUsecase(repo),
        saveDeviceNameUsecase: SaveDeviceNameUsecase(repo),
        setNotificationsEnabledUsecase: SetNotificationsEnabledUsecase(repo),
      );

      bloc.add(const SettingsLoaded());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final nameExpectation = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<SettingsState>().having((s) => s.isLoading, 'isLoading', true),
          isA<SettingsState>().having(
            (s) => s.deviceName,
            'deviceName',
            'Jack Phone',
          ),
        ]),
      );

      bloc.add(const SettingsDeviceNameChanged('Jack Phone'));
      await nameExpectation;

      final notificationExpectation = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<SettingsState>().having((s) => s.isLoading, 'isLoading', true),
          isA<SettingsState>().having(
            (s) => s.notificationsEnabled,
            'notificationsEnabled',
            false,
          ),
        ]),
      );

      bloc.add(const SettingsNotificationsToggled(false));
      await notificationExpectation;
      await bloc.close();
    });
  });
}
