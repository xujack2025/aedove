import 'package:equatable/equatable.dart';

import '../../../domain/entities/transfer_progress_entity.dart';
import '../../../domain/entities/transfer_request_entity.dart';

class TransferState extends Equatable {
  final List<TransferRequestEntity> pendingRequests;
  final Map<String, TransferProgressEntity> activeTransfers;
  final String lastDownloadedPath;
  final String? errorMessage;

  const TransferState({
    required this.pendingRequests,
    required this.activeTransfers,
    required this.lastDownloadedPath,
    this.errorMessage,
  });

  const TransferState.initial()
    : pendingRequests = const [],
      activeTransfers = const {},
      lastDownloadedPath = '',
      errorMessage = null;

  TransferState copyWith({
    List<TransferRequestEntity>? pendingRequests,
    Map<String, TransferProgressEntity>? activeTransfers,
    String? lastDownloadedPath,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return TransferState(
      pendingRequests: pendingRequests ?? this.pendingRequests,
      activeTransfers: activeTransfers ?? this.activeTransfers,
      lastDownloadedPath: lastDownloadedPath ?? this.lastDownloadedPath,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    pendingRequests,
    activeTransfers,
    lastDownloadedPath,
    errorMessage,
  ];
}
