import 'dart:developer' as dev;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request storage-related permissions.
  /// On Android this requests storage and (on Android 11+) manage external storage.
  /// On iOS this requests Photos permission (optional, only needed if saving to Photos).
  static Future<bool> requestStoragePermission() async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Desktop platforms handle file access through system dialogs
        return true;
      } else if (Platform.isAndroid) {
        // Request regular storage permission first
        final status = await Permission.storage.request();
        if (status.isGranted) return true;

        // For Android 11+ try manage external storage. Request it and return
        // granted if the user approves. Some devices or plugin versions may
        // not support this permission, so wrap in try/catch.
        try {
          final manageStatus = await Permission.manageExternalStorage.request();
          if (manageStatus.isGranted) return true;
        } catch (e) {
          print('manageExternalStorage not supported or failed: $e');
        }

        return false;
      } else if (Platform.isIOS) {
        // iOS doesn't require storage permission for basic functionality
        // Only request photos permission if needed for saving to Photos library
        return true;
      }
    } catch (e) {
      print('Error requesting storage permission: $e');
    }
    return false;
  }

  /// Request location permission (used for device discovery via Wi-Fi).
  static Future<bool> requestLocationPermission() async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Desktop platforms handle location access through system settings
        return true;
      } else if (Platform.isAndroid) {
        final status = await Permission.location.request();
        return status.isGranted;
      } else if (Platform.isIOS) {
        final status = await Permission.locationWhenInUse.request();
        return status.isGranted;
      }
    } catch (e) {
      print('Error requesting location permission: $e');
    }
    return false;
  }
}
