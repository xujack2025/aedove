import '../../repositories/device_info_repository.dart';

class GetLocalIpAddressUsecase {
  const GetLocalIpAddressUsecase(this._repository);

  final DeviceInfoRepository _repository;

  Future<String> call() {
    return _repository.getLocalIpAddress();
  }
}
