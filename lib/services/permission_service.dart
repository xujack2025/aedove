import 'dart:io';
import 'package:flutter/foundation.dart';
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
        // Android 13+ (API 33+): Request granular media permissions
        // Android 10-12 (API 29-32): Use scoped storage (no special permission needed for app-specific dirs)
        // Android 9 and below: Request storage permission

        // Try requesting photos/videos/audio permissions (Android 13+)
        try {
          final photosStatus = await Permission.photos.request();
          final videosStatus = await Permission.videos.request();
          final audioStatus = await Permission.audio.request();

          // If any media permission is granted, that's sufficient
          if (photosStatus.isGranted ||
              photosStatus.isLimited ||
              videosStatus.isGranted ||
              videosStatus.isLimited ||
              audioStatus.isGranted ||
              audioStatus.isLimited) {
            return true;
          }
        } catch (e) {
          debugPrint(
            'Media permissions not available (likely older Android): $e',
          );
        }

        // Fallback to legacy storage permission for Android 10-12
        try {
          final status = await Permission.storage.request();
          if (status.isGranted || status.isLimited) return true;
        } catch (e) {
          debugPrint('Storage permission request failed: $e');
        }

        // Even if permissions are denied, app can still save to app-specific storage
        // So return true to allow the app to continue
        debugPrint(
          'Storage permissions not fully granted, will use app-specific storage',
        );
        return true;
      } else if (Platform.isIOS) {
        // iOS doesn't require storage permission for basic functionality
        // Only request photos permission if needed for saving to Photos library
        return true;
      }
    } catch (e) {
      debugPrint('Error requesting storage permission: $e');
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
          debugPrint(
            'iOS location permission already granted/limited: $status',
          );
          return true;
        }

        // If permanently denied, return true anyway since iOS can use Bonjour/mDNS
        // without location permission for local network discovery
        if (status.isPermanentlyDenied) {
          debugPrint(
            'iOS location permission permanently denied. '
            'Local network discovery will still work via Bonjour/mDNS.',
          );
          return true; // Return true to suppress warnings
        }

        // If denied but not permanently, request permission
        if (status.isDenied) {
          debugPrint('iOS requesting location permission...');
          status = await Permission.locationWhenInUse.request();
          debugPrint('iOS location permission result: $status');

          // If still denied after request, that's OK for iOS
          if (status.isPermanentlyDenied || status.isDenied) {
            debugPrint(
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
      debugPrint('Error requesting location permission: $e');
    }
    return false;
  }
}
