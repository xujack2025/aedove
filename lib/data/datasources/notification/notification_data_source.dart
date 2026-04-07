import '../../../services/notification_service.dart';

class NotificationDataSource {
  const NotificationDataSource();

  Future<void> initialize() {
    return NotificationService.initialize();
  }
}
