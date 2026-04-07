import 'package:get_it/get_it.dart';

import '../data/repositories/device_repository_impl.dart';
import '../domain/repositories/device_repository.dart';
import '../domain/usecases/start_discovery_usecase.dart';
import '../domain/usecases/stop_discovery_usecase.dart';
import '../domain/usecases/watch_devices_usecase.dart';
import '../presentation/bloc/discovery/discovery_bloc.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  sl.registerLazySingleton<DeviceRepository>(() => DeviceRepositoryImpl());

  sl.registerLazySingleton<StartDiscoveryUsecase>(
    () => StartDiscoveryUsecase(sl<DeviceRepository>()),
  );

  sl.registerLazySingleton<StopDiscoveryUsecase>(
    () => StopDiscoveryUsecase(sl<DeviceRepository>()),
  );

  sl.registerLazySingleton<WatchDevicesUsecase>(
    () => WatchDevicesUsecase(sl<DeviceRepository>()),
  );

  sl.registerFactory<DiscoveryBloc>(
    () => DiscoveryBloc(
      startDiscoveryUsecase: sl<StartDiscoveryUsecase>(),
      stopDiscoveryUsecase: sl<StopDiscoveryUsecase>(),
      watchDevicesUsecase: sl<WatchDevicesUsecase>(),
    ),
  );
}