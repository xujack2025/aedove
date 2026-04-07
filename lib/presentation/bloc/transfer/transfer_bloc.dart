import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/transfer_progress_entity.dart';
import '../../../domain/entities/transfer_status.dart';
import '../../../domain/usecases/transfer/accept_transfer_usecase.dart';
import '../../../domain/usecases/transfer/deny_transfer_usecase.dart';
import '../../../domain/usecases/transfer/accept_transfer_usecase.dart';
import '../../../domain/usecases/transfer/deny_transfer_usecase.dart';
import '../../../domain/usecases/transfer/watch_file_saved_usecase.dart';
import '../../../domain/usecases/transfer/watch_progress_usecase.dart';
import '../../../domain/usecases/transfer/watch_requests_usecase.dart';
import 'transfer_event.dart';
import 'transfer_state.dart';

class TransferBloc extends Bloc<TransferEvent, TransferState> {
  StreamSubscription<List<TransferRequestEntity>>? _requestsSub;
  StreamSubscription<TransferProgressEntity>? _progressSub;
  StreamSubscription<String>? _fileSavedSub;

  final WatchRequestsUsecase _watchRequestsUsecase;
  final WatchProgressUsecase _watchProgressUsecase;
  final WatchFileSavedUsecase _watchFileSavedUsecase;
  final AcceptTransferUsecase _acceptTransferUsecase;
  final DenyTransferUsecase _denyTransferUsecase;

  TransferBloc({
    required WatchRequestsUsecase watchRequestsUsecase,
    required WatchProgressUsecase watchProgressUsecase,
    required WatchFileSavedUsecase watchFileSavedUsecase,
    required AcceptTransferUsecase acceptTransferUsecase,
    required DenyTransferUsecase denyTransferUsecase,
  }) : _watchRequestsUsecase = watchRequestsUsecase,
       _watchProgressUsecase = watchProgressUsecase,
       _watchFileSavedUsecase = watchFileSavedUsecase,
       _acceptTransferUsecase = acceptTransferUsecase,
       _denyTransferUsecase = denyTransferUsecase,
       super(const TransferState.initial()) {
    on<TransferStarted>(_onStarted);
    on<TransferStopped>(_onStopped);
    on<TransferRequestsUpdated>(_onRequestsUpdated);
    on<TransferProgressUpdated>(_onProgressUpdated);
    on<TransferFileSavedUpdated>(_onFileSavedUpdated);
    on<TransferProgressCleanupRequested>(_onProgressCleanupRequested);
    on<TransferAcceptRequested>(_onAcceptRequested);
    on<TransferDenyRequested>(_onDenyRequested);
    on<TransferAcceptAllRequested>(_onAcceptAllRequested);
    on<TransferDenyAllRequested>(_onDenyAllRequested);
  }

  Future<void> _onStarted(
    TransferStarted event,
    Emitter<TransferState> emit,
  ) async {
    await _requestsSub?.cancel();
    await _progressSub?.cancel();
    await _fileSavedSub?.cancel();

    emit(state.copyWith(clearErrorMessage: true));

    _requestsSub = _watchRequestsUsecase().listen((requests) {
      add(TransferRequestsUpdated(requests));
    });

    _progressSub = _watchProgressUsecase().listen((progress) {
      add(TransferProgressUpdated(progress));
    });

    _fileSavedSub = _watchFileSavedUsecase().listen((path) {
      add(TransferFileSavedUpdated(path));
    });
  }

  Future<void> _onStopped(
    TransferStopped event,
    Emitter<TransferState> emit,
  ) async {
    await _requestsSub?.cancel();
    await _progressSub?.cancel();
    await _fileSavedSub?.cancel();
    _requestsSub = null;
    _progressSub = null;
    _fileSavedSub = null;
    emit(const TransferState.initial());
  }

  void _onRequestsUpdated(
    TransferRequestsUpdated event,
    Emitter<TransferState> emit,
  ) {
    final requests = event.requests
        .where((request) => !state.activeTransfers.containsKey(request.id))
        .toList();

    emit(state.copyWith(pendingRequests: requests, clearErrorMessage: true));
  }

  void _onProgressUpdated(
    TransferProgressUpdated event,
    Emitter<TransferState> emit,
  ) {
    final progress = event.progress;

    final updatedTransfers = Map<String, FileTransferProgress>.from(
      state.activeTransfers,
    );
    updatedTransfers[progress.requestId] = progress;

    final updatedRequests = state.pendingRequests
        .where((request) => request.id != progress.requestId)
        .toList();

    emit(
      state.copyWith(
        pendingRequests: updatedRequests,
        activeTransfers: updatedTransfers,
        clearErrorMessage: true,
      ),
    );

    if (progress.status == TransferStatus.completed ||
        progress.status == TransferStatus.failed) {
      Future.delayed(const Duration(seconds: 2), () {
        add(TransferProgressCleanupRequested(progress.requestId));
      });
    }
  }

  void _onFileSavedUpdated(
    TransferFileSavedUpdated event,
    Emitter<TransferState> emit,
  ) {
    emit(
      state.copyWith(lastDownloadedPath: event.path, clearErrorMessage: true),
    );
  }

  void _onProgressCleanupRequested(
    TransferProgressCleanupRequested event,
    Emitter<TransferState> emit,
  ) {
    final updatedTransfers = Map<String, FileTransferProgress>.from(
      state.activeTransfers,
    )..remove(event.requestId);

    emit(state.copyWith(activeTransfers: updatedTransfers));
  }

  Future<void> _onAcceptRequested(
    TransferAcceptRequested event,
    Emitter<TransferState> emit,
  ) async {
    await _acceptTransferUsecase(event.requestId);
  }

  Future<void> _onDenyRequested(
    TransferDenyRequested event,
    Emitter<TransferState> emit,
  ) async {
    await _denyTransferUsecase(event.requestId);
  }

  Future<void> _onAcceptAllRequested(
    TransferAcceptAllRequested event,
    Emitter<TransferState> emit,
  ) async {
    final requestIds = state.pendingRequests
        .map((request) => request.id)
        .toList();
    for (final requestId in requestIds) {
      await _acceptTransferUsecase(requestId);
    }
  }

  Future<void> _onDenyAllRequested(
    TransferDenyAllRequested event,
    Emitter<TransferState> emit,
  ) async {
    final requestIds = state.pendingRequests
        .map((request) => request.id)
        .toList();
    for (final requestId in requestIds) {
      await _denyTransferUsecase(requestId);
    }
  }

  @override
  Future<void> close() async {
    await _requestsSub?.cancel();
    await _progressSub?.cancel();
    await _fileSavedSub?.cancel();
    return super.close();
  }
}
