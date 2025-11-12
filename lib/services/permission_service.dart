import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request storage-related permissions.
  /// On Android this requests storage and (on Android 11+) manage external storage.
  /// On iOS this requests Photos permission (optional, only needed if saving to Photos).
  /// Returns true if granted or limited access (limited is acceptable for file operations).
  static Future<bool> requestStoragePermission() async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Desktop platforms handle file access through system dialogs
        return true;
      } else if (Platform.isAndroid) {
        // Request regular storage permission first
        final status = await Permission.storage.request();
        // Accept both granted and limited access (Android 13+ allows limited photo/media access)
        if (status.isGranted || status.isLimited) return true;

        // For Android 11+ try manage external storage. Request it and return
        // granted if the user approves. Some devices or plugin versions may
        // not support this permission, so wrap in try/catch.
        try {
          final manageStatus = await Permission.manageExternalStorage.request();
          if (manageStatus.isGranted || manageStatus.isLimited) return true;
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
  /// Returns true if granted or limited access (limited is acceptable).
  static Future<bool> requestLocationPermission() async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Desktop platforms handle location access through system settings
        return true;
      } else if (Platform.isAndroid) {
        bool granted = false;
        try {
          // Try nearby Wi-Fi devices on Android 13+
          final nearby = await Permission.nearbyWifiDevices.request();
          if (nearby.isGranted || nearby.isLimited) granted = true;
        } catch (_) {}

        if (!granted) {
          // Fallback to location if needed on older devices
          final status = await Permission.location.request();
          granted = status.isGranted || status.isLimited;
        }
        return granted;
      } else if (Platform.isIOS) {
        // Check current status first
        var status = await Permission.locationWhenInUse.status;

        // If already granted or limited, return true
        if (status.isGranted || status.isLimited) {
          print('iOS location permission already granted/limited: $status');
          return true;
        }

        // If permanently denied, return true anyway since iOS can use Bonjour/mDNS
        // without location permission for local network discovery
        if (status.isPermanentlyDenied) {
          print(
            'iOS location permission permanently denied. '
            'Local network discovery will still work via Bonjour/mDNS.',
          );
          return true; // Return true to suppress warnings
        }

        // If denied but not permanently, request permission
        if (status.isDenied) {
          print('iOS requesting location permission...');
          status = await Permission.locationWhenInUse.request();
          print('iOS location permission result: $status');

          // If still denied after request, that's OK for iOS
          if (status.isPermanentlyDenied || status.isDenied) {
            print(
              'iOS location permission denied, but local network discovery will still work.',
            );
            return true; // Return true to suppress warnings
          }

          return status.isGranted || status.isLimited;
        }

        // For any other status, return true (iOS doesn't strictly need it)
        return true;
      }
    } catch (e) {
      print('Error requesting location permission: $e');
    }
    return false;
  }
}
