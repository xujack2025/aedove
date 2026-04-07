import 'dart:async';
import 'dart:io';

import 'package:aedove/presentation/pages/tabs/send_error_mapper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SendErrorMapper', () {
    test('returns timeout message for TimeoutException', () {
      final message = SendErrorMapper.sendFilesMessage(
        TimeoutException('request timed out'),
      );

      expect(message, 'Operation timed out. Please try again.');
    });

    test('returns network message for SocketException', () {
      final message = SendErrorMapper.sendFilesMessage(
        const SocketException('no route to host'),
      );

      expect(
        message,
        'Network issue detected. Check your Wi-Fi connection and retry.',
      );
    });

    test('returns file access message for FileSystemException', () {
      final message = SendErrorMapper.pickFilesMessage(
        const FileSystemException('cannot open file'),
      );

      expect(
        message,
        'Some files could not be accessed. Please reselect your files.',
      );
    });

    test('returns permission message for PlatformException', () {
      final message = SendErrorMapper.pickMediaMessage(
        PlatformException(
          code: 'permission_denied',
          message: 'User denied gallery access',
        ),
      );

      expect(message, SendErrorMapper.permissionDeniedMessage);
    });

    test('returns permission message for generic permission text', () {
      final message = SendErrorMapper.sendFilesMessage(
        Exception('Permission denied by OS policy'),
      );

      expect(message, SendErrorMapper.permissionDeniedMessage);
    });

    test('returns fallback and skipped message formatting', () {
      final message = SendErrorMapper.pickFilesMessage(Exception('unknown'));
      final skipped = SendErrorMapper.skippedFilesMessage(
        acceptedCount: 2,
        rejectedCount: 3,
      );

      expect(message, 'Could not pick files. Please try again.');
      expect(skipped, 'Selected 2 file(s). 3 file(s) skipped.');
    });
  });
}
