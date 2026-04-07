import 'package:get_it/get_it.dart';

import '../data/repositories/device_repository_impl.dart';
import '../data/repositories/transfer_repository_impl.dart';
import '../domain/repositories/device_repository.dart';
import '../domain/repositories/transfer_repository.dart';
import '../domain/usecases/discovery/start_discovery_usecase.dart';
import '../domain/usecases/discovery/stop_discovery_usecase.dart';
import '../domain/usecases/discovery/watch_devices_usecase.dart';
import '../domain/usecases/transfer/accept_transfer_usecase.dart';
import '../domain/usecases/transfer/deny_transfer_usecase.dart';
import '../domain/usecases/transfer/watch_file_saved_usecase.dart';
import '../domain/usecases/transfer/watch_progress_usecase.dart';
import '../domain/usecases/transfer/watch_requests_usecase.dart';
import '../presentation/bloc/discovery/discovery_bloc.dart';
import '../presentation/bloc/transfer/transfer_bloc.dart';

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

  sl.registerLazySingleton<TransferRepository>(() => TransferRepositoryImpl());

  sl.registerLazySingleton<WatchRequestsUsecase>(
    () => WatchRequestsUsecase(sl<TransferRepository>()),
  );

  sl.registerLazySingleton<WatchProgressUsecase>(
    () => WatchProgressUsecase(sl<TransferRepository>()),
  );

  sl.registerLazySingleton<WatchFileSavedUsecase>(
    () => WatchFileSavedUsecase(sl<TransferRepository>()),
  );

  sl.registerLazySingleton<AcceptTransferUsecase>(
    () => AcceptTransferUsecase(sl<TransferRepository>()),
  );

  sl.registerLazySingleton<DenyTransferUsecase>(
    () => DenyTransferUsecase(sl<TransferRepository>()),
  );

  sl.registerFactory<TransferBloc>(
    () => TransferBloc(
      watchRequestsUsecase: sl<WatchRequestsUsecase>(),
      watchProgressUsecase: sl<WatchProgressUsecase>(),
      watchFileSavedUsecase: sl<WatchFileSavedUsecase>(),
      acceptTransferUsecase: sl<AcceptTransferUsecase>(),
      denyTransferUsecase: sl<DenyTransferUsecase>(),
    ),
  );
}
