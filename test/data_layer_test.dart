import 'dart:io';

import 'package:aedove/data/models/device_model.dart';
import 'package:aedove/data/models/settings_model.dart';
import 'package:aedove/data/models/transfer_progress_model.dart';
import 'package:aedove/data/models/transfer_request_model.dart';
import 'package:aedove/data/repositories/file_validation_repository_impl.dart';
import 'package:aedove/domain/entities/device_type.dart';
import 'package:aedove/domain/entities/transfer_status.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDeviceServiceModel {
  _FakeDeviceServiceModel({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.lastSeen,
    required this.isOnline,
  });

  final String id;
  final String name;
  final String ip;
  final int port;
  final DateTime lastSeen;
  final bool isOnline;
}

class _FakeTransferRequestServiceModel {
  _FakeTransferRequestServiceModel({
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
  final String? ipAddress;
  final String? targetDeviceIP;
  final String? localFilePath;
}

class _FakeTransferProgressServiceModel {
  _FakeTransferProgressServiceModel({
    required this.requestId,
    required this.fileName,
    required this.totalBytes,
    required this.transferredBytes,
    required this.status,
    required this.startTime,
    required this.errorMessage,
  });

  final String requestId;
  final String fileName;
  final int totalBytes;
  final int transferredBytes;
  final dynamic status;
  final DateTime startTime;
  final String? errorMessage;
}

void main() {
  group('Data layer models', () {
    test('DeviceModel maps service object to entity', () {
      final model = DeviceModel.fromService(
        _FakeDeviceServiceModel(
          id: 'device-1',
          name: 'Office Phone',
          ip: '192.168.1.10',
          port: 8081,
          lastSeen: DateTime.parse('2026-04-07T10:00:00Z'),
          isOnline: true,
        ),
      );

      final entity = model.toEntity();

      expect(model.isOnline, isTrue);
      expect(entity.id, 'device-1');
      expect(entity.name, 'Office Phone');
      expect(entity.ip, '192.168.1.10');
      expect(entity.port, 8081);
      expect(entity.type, DeviceType.unknown);
    });

    test('TransferRequestModel maps service object to entity', () {
      final model = TransferRequestModel.fromService(
        _FakeTransferRequestServiceModel(
          id: 'request-1',
          senderId: 'sender-1',
          senderName: 'Alice',
          fileName: 'photo.jpg',
          fileSize: 1024,
          fileType: 'image/jpeg',
          timestamp: DateTime.parse('2026-04-07T10:00:00Z'),
          ipAddress: '192.168.1.11',
          targetDeviceIP: '192.168.1.10',
          localFilePath: '/tmp/photo.jpg',
        ),
      );

      final entity = model.toEntity();

      expect(entity.id, 'request-1');
      expect(entity.senderId, 'sender-1');
      expect(entity.senderName, 'Alice');
      expect(entity.fileName, 'photo.jpg');
      expect(entity.fileSize, 1024);
      expect(entity.fileType, 'image/jpeg');
      expect(entity.ipAddress, '192.168.1.11');
      expect(entity.targetDeviceIP, '192.168.1.10');
      expect(entity.localFilePath, '/tmp/photo.jpg');
    });

    test('TransferProgressModel maps transfer status correctly', () {
      final model = TransferProgressModel.fromService(
        _FakeTransferProgressServiceModel(
          requestId: 'request-1',
          fileName: 'video.mp4',
          totalBytes: 2048,
          transferredBytes: 1024,
          status: TransferStatus.transferring,
          startTime: DateTime.parse('2026-04-07T10:00:00Z'),
          errorMessage: null,
        ),
      );

      final entity = model.toEntity();

      expect(entity.requestId, 'request-1');
      expect(entity.fileName, 'video.mp4');
      expect(entity.totalBytes, 2048);
      expect(entity.transferredBytes, 1024);
      expect(entity.status, TransferStatus.transferring);
      expect(entity.startTime, DateTime.parse('2026-04-07T10:00:00Z'));
      expect(entity.errorMessage, isNull);
    });

    test('SettingsModel maps to entity', () {
      final entity = SettingsModel(
        deviceName: 'My Device',
        deviceId: 'device-1',
        notificationsEnabled: false,
      ).toEntity();

      expect(entity.deviceName, 'My Device');
      expect(entity.deviceId, 'device-1');
      expect(entity.notificationsEnabled, isFalse);
    });
  });

  group('FileValidationRepositoryImpl', () {
    test('accepts existing files and rejects invalid files', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'aedove_validation_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final imageFile = File('${tempDir.path}/photo.jpg');
      await imageFile.writeAsString('fake image bytes');

      final textFile = File('${tempDir.path}/notes.txt');
      await textFile.writeAsString('hello');

      final emptyFile = File('${tempDir.path}/empty.jpg');
      await emptyFile.create();

      final repository = FileValidationRepositoryImpl();
      final result = await repository.validatePaths(
        paths: [
          imageFile.path,
          textFile.path,
          emptyFile.path,
          '',
          '${tempDir.path}/missing.jpg',
        ],
        mediaOnly: true,
      );

      expect(result.files.map((file) => file.path), [imageFile.path]);
      expect(result.rejectedCount, 4);
    });

    test('accepts non-media files when mediaOnly is false', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'aedove_validation_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final textFile = File('${tempDir.path}/notes.txt');
      await textFile.writeAsString('hello');

      final repository = FileValidationRepositoryImpl();
      final result = await repository.validatePaths(
        paths: [textFile.path],
        mediaOnly: false,
      );

      expect(result.files.map((file) => file.path), [textFile.path]);
      expect(result.rejectedCount, 0);
    });
  });
}
