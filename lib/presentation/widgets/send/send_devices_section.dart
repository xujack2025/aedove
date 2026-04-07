import 'package:aedove/domain/entities/device_entity.dart';
import 'package:aedove/presentation/pages/tabs/send_device_transfer_ui_state.dart';
import 'package:aedove/presentation/widgets/send/send_device_card.dart';
import 'package:aedove/presentation/widgets/send/send_empty_devices_state.dart';
import 'package:flutter/material.dart';

class SendDevicesSection extends StatelessWidget {
  const SendDevicesSection({
    super.key,
    required this.devices,
    required this.hasSelectedFiles,
    required this.deviceTransferUiState,
    required this.onSendTap,
  });

  final List<DeviceEntity> devices;
  final bool hasSelectedFiles;
  final SendDeviceTransferUiState deviceTransferUiState;
  final Future<void> Function(DeviceEntity device) onSendTap;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const SendEmptyDevicesState();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: devices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final device = devices[index];
        return SendDeviceCard(
          device: device,
          hasSelectedFiles: hasSelectedFiles,
          isSending: deviceTransferUiState.isSending(device.id),
          sentSuccessfully: deviceTransferUiState.isSentSuccessfully(device.id),
          onSendTap: onSendTap,
        );
      },
    );
  }
}
