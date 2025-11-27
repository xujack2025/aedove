import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

class NotificationService {
  static Future<void> initialize() async {
    AwesomeNotifications().initialize(
      'resource://drawable/ic_stat_aedove_logo', // Custom notification icon
      [
        NotificationChannel(
          channelKey: 'file_transfer',
          channelName: 'File Transfer',
          channelDescription: 'Notifications for incoming file transfers',
          importance: NotificationImportance.High,
          defaultColor: Color(0xFF0175C2),
          ledColor: Colors.white,
        ),
        NotificationChannel(
          channelKey: 'file_received',
          channelName: 'File Received',
          channelDescription: 'Notifications after receiving files',
          importance: NotificationImportance.High,
          defaultColor: Color(0xFF0175C2),
          ledColor: Colors.white,
        ),
        NotificationChannel(
          channelKey: 'file_sent',
          channelName: 'File Sent',
          channelDescription: 'Notifications after successfully sending files',
          importance: NotificationImportance.High,
          defaultColor: Color(0xFF0175C2),
          ledColor: Colors.white,
        ),
        NotificationChannel(
          channelKey: 'device_discovered',
          channelName: 'Device Discovery',
          channelDescription: 'Notifications when a device is found',
          importance: NotificationImportance.Low,
          defaultColor: Color(0xFF0175C2),
          ledColor: Colors.white,
        ),
      ],
    );

    // Ask permission on iOS, macOS & Web:
    await AwesomeNotifications().isNotificationAllowed().then((allowed) {
      if (!allowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    // Listen to notification taps
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onNotificationTapped,
    );
  }

  static Future<void> showFileTransferNotification({
    required String senderId,
    required String fileName,
    required String fileSize,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: senderId.hashCode,
        channelKey: 'file_transfer',
        title: 'Incoming File Transfer',
        body: 'File: $fileName ($fileSize)',
        payload: {
          'action': 'file_transfer_request',
          'sender_id': senderId,
          'file_name': fileName,
          'file_size': fileSize,
        },
      ),
    );
  }

  static Future<void> showFileSentNotification({
    required String fileName,
    required String fileSize,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        channelKey: 'file_sent',
        title: 'File Sent Successfully',
        body: 'File: $fileName ($fileSize)',
        notificationLayout: NotificationLayout.Default,
        payload: {
          'action': 'file_sent',
          'file_name': fileName,
          'file_size': fileSize,
        },
      ),
    );
  }

  static Future<void> showFileReceivedNotification({
    required String fileName,
    required String fileSize,
    required String filePath,
    bool isIOS = false,
  }) async {
    String notificationMessage;
    if (isIOS) {
      notificationMessage = 'Saved to Documents\nFile: $fileName ($fileSize)';
    } else if (Platform.isWindows) {
      notificationMessage = 'Saved to Downloads\nFile: $fileName ($fileSize)';
    } else {
      notificationMessage = 'File: $fileName ($fileSize)';
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        channelKey: 'file_received',
        title: 'File Received',
        body: notificationMessage,
        payload: {'action': 'file_received', 'file_path': filePath},
      ),
    );
  }

  static Future<void> _onNotificationTapped(ReceivedAction action) async {
    final payload = action.payload ?? {};

    switch (payload['action']) {
      case 'file_transfer_request':
        debugPrint('File transfer request from ${payload['sender_id']}');
        break;

      case 'file_received':
        debugPrint('Open file at: ${payload['file_path']}');
        break;
    }
  }
}

/*class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Initialize notification settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  static Future<void> showFileTransferNotification({
    required String senderId,
    required String fileName,
    required String fileSize,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'file_transfer',
      'File Transfer',
      channelDescription: 'Notifications for incoming file transfers',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails, // We can use the same settings for macOS
    );

    await _notifications.show(
      senderId.hashCode,
      'Incoming File Transfer',
      'File: $fileName ($fileSize)',
      details,
      payload: jsonEncode({
        'sender_id': senderId,
        'file_name': fileName,
        'file_size': fileSize,
        'action': 'file_transfer_request',
      }),
    );
  }

  static Future<void> showFileReceivedNotification({
    required String fileName,
    required String fileSize,
    required String filePath,
    bool isIOS = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'file_received',
      'File Received',
      channelDescription: 'Notifications for received files',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      autoCancel: true,
      onlyAlertOnce: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
      threadIdentifier: 'file_received',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails, // We can use the same settings for macOS
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch.toSigned(32);

    String notificationMessage;
    if (isIOS) {
      notificationMessage =
          '📥 Location: Documents folder\nFile: $fileName ($fileSize)';
    } else {
      final folder = filePath.replaceAll('/storage/emulated/0/', '');
      notificationMessage = '📥 Location: $folder\nFile: $fileName ($fileSize)';
    }

    await _notifications.show(
      notificationId,
      'File Received',
      notificationMessage,
      details,
      payload: jsonEncode({
        'action': 'file_received',
        'file_path': filePath,
        'notification_id': notificationId,
        'is_ios': isIOS,
      }),
    );
  }

  static Future<void> showFileSentNotification({
    required String fileName,
    required String fileSize,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'file_sent',
      'File Sent',
      channelDescription: 'Notifications for sent files',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails, // We can use the same settings for macOS
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.toSigned(32),
      'File Sent',
      'File: $fileName ($fileSize)',
      details,
    );
  }

  static Future<void> showDeviceDiscoveredNotification({
    required String deviceName,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'device_discovered',
      'Device Discovered',
      channelDescription: 'Notifications for discovered devices',
      importance: Importance.low,
      priority: Priority.low,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails, // We can use the same settings for macOS
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.toSigned(32),
      'Device Discovered',
      'New device: $deviceName',
      details,
    );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final payload = jsonDecode(response.payload!);
        final action = payload['action'];

        switch (action) {
          case 'file_transfer_request':
            _handleFileTransferRequest(payload);
            break;
          case 'file_received':
            _handleFileReceived(payload);
            break;
        }

        // Cancel the notification if it has an ID
        if (payload.containsKey('notification_id')) {
          _notifications.cancel(payload['notification_id']);
        }
      } catch (e) {
        debugPrint('Error handling notification tap: $e');
      }
    }
  }

  static void _handleFileReceived(Map<String, dynamic> payload) {
    // Here you could implement opening the file or its containing folder
    final filePath = payload['file_path'];
    debugPrint('Opening received file: $filePath');
  }

  static void _handleFileTransferRequest(Map<String, dynamic> payload) {
    // This would typically open the app to the file transfer screen
    // For now, we'll just print the details
    debugPrint('File transfer request from: ${payload['sender_id']}');
    debugPrint('File: ${payload['file_name']} (${payload['file_size']})');
  }
}*/
