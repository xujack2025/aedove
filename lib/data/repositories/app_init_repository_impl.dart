import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../../domain/repositories/app_init_repository.dart';
import '../../services/background_service.dart';
import '../../services/notification_service.dart';
import '../../services/permission_service.dart';

class AppInitRepositoryImpl implements AppInitRepository {
  const AppInitRepositoryImpl();

  @override
  Future<void> initialize() async {
    await BackgroundService.initialize();
    await NotificationService.initialize();
    await _requestRuntimePermissions();
  }

  Future<void> _requestRuntimePermissions() async {
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted && !storageStatus.isLimited) {
        await PermissionService.requestStoragePermission();
      }
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final locationStatus = await Permission.locationWhenInUse.status;
      final isUsable =
          locationStatus.isGranted ||
          locationStatus.isLimited ||
          (Platform.isIOS && locationStatus.isPermanentlyDenied);

      if (!isUsable) {
        await PermissionService.requestLocationPermission();
      }
    }
  }
}
