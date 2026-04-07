import '../../domain/entities/transfer_request_entity.dart';

class TransferRequestModel {
  const TransferRequestModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.timestamp,
    required this.ipAddress,
    required this.targetDeviceIP,
    required this.localFilePath,
  });

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

  factory TransferRequestModel.fromService(dynamic request) {
    return TransferRequestModel(
      id: request.id as String,
      senderId: request.senderId as String,
      senderName: request.senderName as String,
      fileName: request.fileName as String,
      fileSize: request.fileSize as int,
      fileType: request.fileType as String,
      timestamp: request.timestamp as DateTime,
      ipAddress: request.ipAddress as String? ?? '',
      targetDeviceIP: request.targetDeviceIP as String? ?? '',
      localFilePath: request.localFilePath as String?,
    );
  }

  TransferRequestEntity toEntity() {
    return TransferRequestEntity(
      id: id,
      senderId: senderId,
      senderName: senderName,
      fileName: fileName,
      fileSize: fileSize,
      fileType: fileType,
      timestamp: timestamp,
      ipAddress: ipAddress,
      targetDeviceIP: targetDeviceIP,
      localFilePath: localFilePath,
    );
  }
}
