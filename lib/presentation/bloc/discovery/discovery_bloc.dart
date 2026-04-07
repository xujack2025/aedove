import 'dart:async';

import 'package:aedove/domain/entities/device_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/start_discovery_usecase.dart';
import '../../../domain/usecases/stop_discovery_usecase.dart';
import '../../../domain/usecases/watch_devices_usecase.dart';
import 'discovery_event.dart';
import 'discovery_state.dart';

class DiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState> {
  final StartDiscoveryUsecase _startDiscoveryUsecase;
  final StopDiscoveryUsecase _stopDiscoveryUsecase;
  final WatchDevicesUsecase _watchDevicesUsecase;

  StreamSubscription? _deviceSub;

  List<DeviceEntity> _currentDevices() => state.devices;

  DiscoveryBloc({
    required StartDiscoveryUsecase startDiscoveryUsecase,
    required StopDiscoveryUsecase stopDiscoveryUsecase,
    required WatchDevicesUsecase watchDevicesUsecase,
  }) : _startDiscoveryUsecase = startDiscoveryUsecase,
       _stopDiscoveryUsecase = stopDiscoveryUsecase,
       _watchDevicesUsecase = watchDevicesUsecase,
       super(const DiscoveryInitial()) {
    on<DiscoveryStarted>(_onStarted);
    on<DiscoveryStopped>(_onStopped);
    on<DevicesUpdated>(_onDevicesUpdate);
  }

  FutureOr<void> _onStarted(
    DiscoveryStarted event,
    Emitter<DiscoveryState> emit,
  ) async {
    emit(DiscoveryLoading(devices: _currentDevices()));

    await _deviceSub?.cancel();
    _deviceSub = _watchDevicesUsecase().listen(
      (devices) => add(DevicesUpdated(devices)),
      onError: (error) => addError(error),
    );

    try {
      await _startDiscoveryUsecase();
    } catch (e) {
      emit(DiscoveryError(message: e.toString(), devices: _currentDevices()));
    }
  }

  FutureOr<void> _onStopped(
    DiscoveryStopped event,
    Emitter<DiscoveryState> emit,
  ) async {
    await _deviceSub?.cancel();
    _deviceSub = null;

    try {
      await _stopDiscoveryUsecase();
      emit(DiscoveryInitial());
    } catch (e) {
      emit(DiscoveryError(message: e.toString(), devices: _currentDevices()));
    }
  }

  FutureOr<void> _onDevicesUpdate(
    DevicesUpdated event,
    Emitter<DiscoveryState> emit,
  ) {
    emit(DiscoveryLoaded(devices: event.devices));
  }

  @override
  Future<void> close() async {
    await _deviceSub?.cancel();
    return super.close();
  }
}
