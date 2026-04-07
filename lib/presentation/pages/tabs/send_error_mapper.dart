import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class SendErrorMapper {
  const SendErrorMapper._();

  static const String noFilesSelectedMessage =
      'Please select files before sending.';
  static const String permissionDeniedMessage =
      'Permission denied. Please grant photo access.';

  static String pickFilesMessage(Object error) {
    return _map(error, fallback: 'Could not pick files. Please try again.');
  }

  static String pickMediaMessage(Object error) {
    return _map(error, fallback: 'Could not pick media. Please try again.');
  }

  static String selectMediaMessage(Object error) {
    return _map(
      error,
      fallback: 'Could not process selected media. Please try again.',
    );
  }

  static String sendFilesMessage(Object error) {
    return _map(
      error,
      fallback: 'Could not send files. Please check your connection and retry.',
    );
  }

  static String skippedFilesMessage({
    required int acceptedCount,
    required int rejectedCount,
  }) {
    return 'Selected $acceptedCount file(s). $rejectedCount file(s) skipped.';
  }

  static String _map(Object error, {required String fallback}) {
    if (error is TimeoutException) {
      return 'Operation timed out. Please try again.';
    }

    if (error is SocketException) {
      return 'Network issue detected. Check your Wi-Fi connection and retry.';
    }

    if (error is FileSystemException) {
      return 'Some files could not be accessed. Please reselect your files.';
    }

    if (error is PlatformException) {
      final normalized = '${error.code} ${error.message ?? ''}'.toLowerCase();
      if (normalized.contains('permission') ||
          normalized.contains('denied') ||
          normalized.contains('not authorized')) {
        return permissionDeniedMessage;
      }
    }

    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('denied')) {
      return permissionDeniedMessage;
    }

    return fallback;
  }
}
