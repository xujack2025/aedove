import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:aedove/services/device_discovery_service.dart';
import 'package:aedove/services/file_transfer_service.dart';
import 'package:aedove/services/permission_service.dart';

class BackgroundService {
  static const String _deviceIdKey = 'device_id';
  static const String _deviceNameKey = 'device_name';

  static Future<void> initialize() async {
    // Initialize device ID and name
    await _initializeDeviceInfo();

    // Start background services
    await _startBackgroundServices();
  }

  static Future<void> _initializeDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceInfo = DeviceInfoPlugin();

    // Generate or get device ID
    String? deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    // Get or set device name
    String? deviceName = prefs.getString(_deviceNameKey);
    if (deviceName == null) {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
      } else {
        deviceName = 'AeDove Device';
      }
      await prefs.setString(_deviceNameKey, deviceName);
    }
  }

  static Future<void> _startBackgroundServices() async {
    if (!Platform.isMacOS) {
      // Request necessary runtime permissions before starting services.
      // Storage permission for saving received files, and location for discovery.
      // Note: Both requestStoragePermission and requestLocationPermission
      // return true for both granted and limited access.
      final storageOk = await PermissionService.requestStoragePermission();
      if (!storageOk) {
        print(
          'Warning: storage permission not granted. Receiving files may fail on Android.',
        );
      }

      final locationOk = await PermissionService.requestLocationPermission();
      if (!locationOk) {
        print(
          'Warning: location permission not granted. Device discovery may be limited.',
        );
      }
    }

    // Start file transfer service first so discovery can advertise correct port
    await FileTransferService.start();

    // Start device discovery service after server is ready
    await DeviceDiscoveryService.start();
  }

  static Future<void> stop() async {
    await DeviceDiscoveryService.stop();
    await FileTransferService.stop();
  }
}
