import 'package:equatable/equatable.dart';

import 'transfer_status.dart';

class TransferProgressEntity extends Equatable {
  final String requestId;
  final String fileName;
  final int totalBytes;
  final int transferredBytes;
  final TransferStatus status;
  final DateTime startTime;
  final String? errorMessage;

  const TransferProgressEntity({
    required this.requestId,
    required this.fileName,
    required this.totalBytes,
    required this.transferredBytes,
    required this.status,
    required this.startTime,
    this.errorMessage,
  });

  double get progress => totalBytes > 0 ? transferredBytes / totalBytes : 0.0;

  Duration get elapsed => DateTime.now().difference(startTime);

  Duration? get estimatedTimeRemaining {
    if (transferredBytes <= 0 || status != TransferStatus.transferring) {
      return null;
    }

    final bytesPerSecond = transferredBytes / elapsed.inSeconds;
    if (bytesPerSecond <= 0) return null;

    final remainingBytes = totalBytes - transferredBytes;
    final secondsRemaining = remainingBytes / bytesPerSecond;
    return Duration(seconds: secondsRemaining.ceil());
  }

  String get progressPercent => '${(progress * 100).toStringAsFixed(0)}%';

  @override
  List<Object?> get props => [
    requestId,
    fileName,
    totalBytes,
    transferredBytes,
    status,
    startTime,
    errorMessage,
  ];
}
