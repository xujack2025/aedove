import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../models/device_info_model.dart';

class DeviceInfoDataSource {
  const DeviceInfoDataSource();

  Future<DeviceInfoModel> getLocalIpAddress() async {
    String ipAddress = 'Unknown';

    if (Platform.isWindows) {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            ipAddress = addr.address;
            break;
          }
        }
        if (ipAddress != 'Unknown') {
          break;
        }
      }
      return DeviceInfoModel(ipAddress: ipAddress);
    }

    final networkInfo = NetworkInfo();
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none) {
      ipAddress = await networkInfo.getWifiIP() ?? 'Unknown';
    }

    return DeviceInfoModel(ipAddress: ipAddress);
  }
}
