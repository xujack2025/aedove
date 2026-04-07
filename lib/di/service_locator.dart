import 'package:get_it/get_it.dart';

import '../data/repositories/device_repository_impl.dart';
import '../data/repositories/device_info_repository_impl.dart';
import '../data/repositories/ad_repository_impl.dart';
import '../data/repositories/app_init_repository_impl.dart';
import '../data/repositories/file_access_repository_impl.dart';
import '../data/repositories/file_validation_repository_impl.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../data/repositories/transfer_repository_impl.dart';
import '../data/datasources/app_init/app_init_data_source.dart';
import '../data/datasources/file_access/file_access_data_source.dart';
import '../data/datasources/device/device_discovery_data_source.dart';
import '../data/datasources/device_info/device_info_data_source.dart';
import '../data/datasources/notification/notification_data_source.dart';
import '../data/datasources/permission/permission_data_source.dart';
import '../data/datasources/settings/settings_local_data_source.dart';
import '../data/datasources/transfer/transfer_data_source.dart';
import '../domain/repositories/ad_repository.dart';
import '../domain/repositories/app_init_repository.dart';
import '../domain/repositories/device_repository.dart';
import '../domain/repositories/device_info_repository.dart';
import '../domain/repositories/file_access_repository.dart';
import '../domain/repositories/file_validation_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/repositories/transfer_repository.dart';
import '../domain/usecases/app_init/initialize_app_usecase.dart';
import '../domain/usecases/ads/fetch_ad_schedule_usecase.dart';
import '../domain/usecases/ads/rotate_ad_item_usecase.dart';
import '../domain/usecases/discovery/start_discovery_usecase.dart';
import '../domain/usecases/discovery/stop_discovery_usecase.dart';
import '../domain/usecases/discovery/watch_devices_usecase.dart';
import '../domain/usecases/device_info/get_local_ip_address_usecase.dart';
import '../domain/usecases/settings/load_settings_usecase.dart';
import '../domain/usecases/settings/save_device_name_usecase.dart';
import '../domain/usecases/settings/set_notifications_enabled_usecase.dart';
import '../domain/usecases/transfer/accept_transfer_usecase.dart';
import '../domain/usecases/transfer/deny_transfer_usecase.dart';
import '../domain/usecases/file_access/open_file_usecase.dart';
import '../domain/usecases/file_access/show_in_file_manager_usecase.dart';
import '../domain/usecases/transfer/send_file_usecase.dart';
import '../domain/usecases/transfer/watch_file_saved_usecase.dart';
import '../domain/usecases/transfer/watch_progress_usecase.dart';
import '../domain/usecases/transfer/watch_requests_usecase.dart';
import '../domain/usecases/transfer/validate_selected_files_usecase.dart';
import '../presentation/bloc/app_init/app_init_bloc.dart';
import '../presentation/bloc/ads/ads_bloc.dart';
import '../presentation/bloc/discovery/discovery_bloc.dart';
import '../presentation/bloc/settings/settings_bloc.dart';
import '../presentation/bloc/transfer/transfer_bloc.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  sl.registerLazySingleton<DeviceDiscoveryDataSource>(
    () => const DeviceDiscoveryDataSource(),
  );

  sl.registerLazySingleton<DeviceRepository>(
    () => DeviceRepositoryImpl(sl<DeviceDiscoveryDataSource>()),
  );

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

  sl.registerLazySingleton<TransferDataSource>(
    () => const TransferDataSource(),
  );

  sl.registerLazySingleton<TransferRepository>(
    () => TransferRepositoryImpl(sl<TransferDataSource>()),
  );

  sl.registerLazySingleton<WatchRequestsUsecase>(
    () => WatchRequestsUsecase(sl<TransferRepository>()),
  );

  sl.registerLazySingleton<SendFileUsecase>(
    () => SendFileUsecase(sl<TransferRepository>()),
  );

  sl.registerLazySingleton<FileValidationRepository>(
    () => const FileValidationRepositoryImpl(),
  );

  sl.registerLazySingleton<ValidateSelectedFilesUsecase>(
    () => ValidateSelectedFilesUsecase(sl<FileValidationRepository>()),
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

  sl.registerLazySingleton<AdRepository>(() => const AdRepositoryImpl());

  sl.registerLazySingleton<FetchAdScheduleUsecase>(
    () => FetchAdScheduleUsecase(sl<AdRepository>()),
  );

  sl.registerLazySingleton<RotateAdItemUsecase>(
    () => const RotateAdItemUsecase(),
  );

  sl.registerFactory<AdsBloc>(
    () => AdsBloc(
      fetchAdScheduleUsecase: sl<FetchAdScheduleUsecase>(),
      rotateAdItemUsecase: sl<RotateAdItemUsecase>(),
    ),
  );

  sl.registerLazySingleton<AppInitDataSource>(() => const AppInitDataSource());

  sl.registerLazySingleton<NotificationDataSource>(
    () => const NotificationDataSource(),
  );

  sl.registerLazySingleton<PermissionDataSource>(
    () => const PermissionDataSource(),
  );

  sl.registerLazySingleton<AppInitRepository>(
    () => AppInitRepositoryImpl(
      sl<AppInitDataSource>(),
      sl<NotificationDataSource>(),
      sl<PermissionDataSource>(),
    ),
  );

  sl.registerLazySingleton<InitializeAppUsecase>(
    () => InitializeAppUsecase(sl<AppInitRepository>()),
  );

  sl.registerFactory<AppInitBloc>(
    () => AppInitBloc(initializeAppUsecase: sl<InitializeAppUsecase>()),
  );

  sl.registerLazySingleton<SettingsLocalDataSource>(
    () => const SettingsLocalDataSource(),
  );

  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(sl<SettingsLocalDataSource>()),
  );

  sl.registerLazySingleton<LoadSettingsUsecase>(
    () => LoadSettingsUsecase(sl<SettingsRepository>()),
  );

  sl.registerLazySingleton<SaveDeviceNameUsecase>(
    () => SaveDeviceNameUsecase(sl<SettingsRepository>()),
  );

  sl.registerLazySingleton<SetNotificationsEnabledUsecase>(
    () => SetNotificationsEnabledUsecase(sl<SettingsRepository>()),
  );

  sl.registerFactory<SettingsBloc>(
    () => SettingsBloc(
      loadSettingsUsecase: sl<LoadSettingsUsecase>(),
      saveDeviceNameUsecase: sl<SaveDeviceNameUsecase>(),
      setNotificationsEnabledUsecase: sl<SetNotificationsEnabledUsecase>(),
    ),
  );

  sl.registerLazySingleton<FileAccessDataSource>(
    () => const FileAccessDataSource(),
  );

  sl.registerLazySingleton<FileAccessRepository>(
    () => FileAccessRepositoryImpl(sl<FileAccessDataSource>()),
  );

  sl.registerLazySingleton<OpenFileUsecase>(
    () => OpenFileUsecase(sl<FileAccessRepository>()),
  );

  sl.registerLazySingleton<ShowInFileManagerUsecase>(
    () => ShowInFileManagerUsecase(sl<FileAccessRepository>()),
  );

  sl.registerLazySingleton<DeviceInfoDataSource>(
    () => const DeviceInfoDataSource(),
  );

  sl.registerLazySingleton<DeviceInfoRepository>(
    () => DeviceInfoRepositoryImpl(sl<DeviceInfoDataSource>()),
  );

  sl.registerLazySingleton<GetLocalIpAddressUsecase>(
    () => GetLocalIpAddressUsecase(sl<DeviceInfoRepository>()),
  );
}
