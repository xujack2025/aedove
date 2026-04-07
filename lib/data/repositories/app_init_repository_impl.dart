import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../../domain/repositories/app_init_repository.dart';
import '../datasources/app_init/app_init_data_source.dart';
import '../datasources/notification/notification_data_source.dart';
import '../datasources/permission/permission_data_source.dart';

class AppInitRepositoryImpl implements AppInitRepository {
  const AppInitRepositoryImpl(
    this._dataSource,
    this._notificationDataSource,
    this._permissionDataSource,
  );

  final AppInitDataSource _dataSource;
  final NotificationDataSource _notificationDataSource;
  final PermissionDataSource _permissionDataSource;

  @override
  Future<void> initialize() async {
    await _dataSource.initialize();
    await _notificationDataSource.initialize();
    await _requestRuntimePermissions();
  }

  Future<void> _requestRuntimePermissions() async {
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted && !storageStatus.isLimited) {
        await _permissionDataSource.requestStoragePermission();
      }
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final locationStatus = await Permission.locationWhenInUse.status;
      final isUsable =
          locationStatus.isGranted ||
          locationStatus.isLimited ||
          (Platform.isIOS && locationStatus.isPermanentlyDenied);

      if (!isUsable) {
        await _permissionDataSource.requestLocationPermission();
      }
    }
  }
}
