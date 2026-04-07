import '../../../services/background_service.dart';

class AppInitDataSource {
  const AppInitDataSource();

  Future<void> initialize() {
    return BackgroundService.initialize();
  }
}
