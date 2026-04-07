import 'package:aedove/domain/entities/device_entity.dart';
import 'package:flutter/material.dart';

class SendDeviceCard extends StatelessWidget {
  const SendDeviceCard({
    super.key,
    required this.device,
    required this.hasSelectedFiles,
    required this.isSending,
    required this.sentSuccessfully,
    required this.onSendTap,
  });

  final DeviceEntity device;
  final bool hasSelectedFiles;
  final bool isSending;
  final bool sentSuccessfully;
  final Future<void> Function(DeviceEntity device) onSendTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.indigo.withAlpha((0.1 * 255).round()),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.devices_rounded, color: Colors.indigo),
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${device.ip}:${device.port}',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: hasSelectedFiles
            ? ElevatedButton(
                onPressed: (isSending || sentSuccessfully)
                    ? null
                    : () => onSendTap(device),
                style: ElevatedButton.styleFrom(
                  backgroundColor: sentSuccessfully
                      ? Colors.green
                      : Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  elevation: 0,
                ),
                child: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : sentSuccessfully
                    ? const Icon(Icons.check, size: 20)
                    : const Text('Send'),
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Ready',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
