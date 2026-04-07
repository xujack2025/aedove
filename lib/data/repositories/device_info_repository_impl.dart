import '../../domain/repositories/device_info_repository.dart';
import '../datasources/device_info/device_info_data_source.dart';

class DeviceInfoRepositoryImpl implements DeviceInfoRepository {
  const DeviceInfoRepositoryImpl(this._dataSource);

  final DeviceInfoDataSource _dataSource;

  @override
  Future<String> getLocalIpAddress() async {
    return (await _dataSource.getLocalIpAddress()).ipAddress;
  }
}
