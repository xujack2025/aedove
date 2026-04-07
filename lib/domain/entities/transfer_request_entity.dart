import 'package:equatable/equatable.dart';

class TransferRequestEntity extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String fileName;
  final int fileSize;
  final String fileType;
  final DateTime timestamp;
  final String ipAddress;
  final String targetDeviceIP;
  final String? localFilePath;

  const TransferRequestEntity({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.timestamp,
    this.ipAddress = '',
    this.targetDeviceIP = '',
    this.localFilePath,
  });

  @override
  List<Object?> get props => [
    id,
    senderId,
    senderName,
    fileName,
    fileSize,
    fileType,
    timestamp,
    ipAddress,
    targetDeviceIP,
    localFilePath,
  ];
}
