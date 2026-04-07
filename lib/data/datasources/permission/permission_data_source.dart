import '../../../services/permission_service.dart';

class PermissionDataSource {
  const PermissionDataSource();

  Future<bool> requestStoragePermission() {
    return PermissionService.requestStoragePermission();
  }

  Future<bool> requestLocationPermission() {
    return PermissionService.requestLocationPermission();
  }
}
