import 'package:equatable/equatable.dart';

import '../../../domain/entities/transfer_progress_entity.dart';
import '../../../domain/entities/transfer_request_entity.dart';

sealed class TransferEvent extends Equatable {
  const TransferEvent();

  @override
  List<Object?> get props => [];
}

class TransferStarted extends TransferEvent {
  const TransferStarted();
}

class TransferStopped extends TransferEvent {
  const TransferStopped();
}

class TransferRequestsUpdated extends TransferEvent {
  final List<TransferRequestEntity> requests;

  const TransferRequestsUpdated(this.requests);

  @override
  List<Object?> get props => [requests];
}

class TransferProgressUpdated extends TransferEvent {
  final TransferProgressEntity progress;

  const TransferProgressUpdated(this.progress);

  @override
  List<Object?> get props => [progress];
}

class TransferFileSavedUpdated extends TransferEvent {
  final String path;

  const TransferFileSavedUpdated(this.path);

  @override
  List<Object?> get props => [path];
}

class TransferProgressCleanupRequested extends TransferEvent {
  final String requestId;

  const TransferProgressCleanupRequested(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

class TransferAcceptRequested extends TransferEvent {
  final String requestId;

  const TransferAcceptRequested(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

class TransferDenyRequested extends TransferEvent {
  final String requestId;

  const TransferDenyRequested(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

class TransferAcceptAllRequested extends TransferEvent {
  const TransferAcceptAllRequested();
}

class TransferDenyAllRequested extends TransferEvent {
  const TransferDenyAllRequested();
}
