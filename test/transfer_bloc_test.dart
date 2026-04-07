import 'dart:async';

import 'package:aedove/domain/entities/transfer_progress_entity.dart';
import 'package:aedove/domain/entities/transfer_request_entity.dart';
import 'package:aedove/domain/entities/transfer_status.dart';
import 'package:aedove/domain/repositories/transfer_repository.dart';
import 'package:aedove/domain/usecases/transfer/accept_transfer_usecase.dart';
import 'package:aedove/domain/usecases/transfer/deny_transfer_usecase.dart';
import 'package:aedove/domain/usecases/transfer/watch_file_saved_usecase.dart';
import 'package:aedove/domain/usecases/transfer/watch_progress_usecase.dart';
import 'package:aedove/domain/usecases/transfer/watch_requests_usecase.dart';
import 'package:aedove/presentation/bloc/transfer/transfer_bloc.dart';
import 'package:aedove/presentation/bloc/transfer/transfer_event.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTransferRepository implements TransferRepository {
  final StreamController<List<TransferRequestEntity>> requestsController =
      StreamController<List<TransferRequestEntity>>.broadcast();
  final StreamController<TransferProgressEntity> progressController =
      StreamController<TransferProgressEntity>.broadcast();
  final StreamController<String> savedController =
      StreamController<String>.broadcast();

  final List<String> accepted = [];
  final List<String> denied = [];

  @override
  Future<void> acceptTransfer(String requestId) async {
    accepted.add(requestId);
  }

  @override
  Future<void> denyTransfer(String requestId) async {
    denied.add(requestId);
  }

  @override
  Future<void> sendFile({
    required String targetDeviceId,
    required String targetDeviceIP,
    required String filePath,
    required String fileName,
    required int targetDevicePort,
  }) async {}

  @override
  Stream<String> watchFileSaved() => savedController.stream;

  @override
  Stream<TransferProgressEntity> watchProgress() => progressController.stream;

  @override
  Stream<List<TransferRequestEntity>> watchRequests() =>
      requestsController.stream;

  Future<void> dispose() async {
    await requestsController.close();
    await progressController.close();
    await savedController.close();
  }
}

TransferRequestEntity _request(String id) {
  return TransferRequestEntity(
    id: id,
    senderId: 's1',
    senderName: 'sender',
    fileName: 'a.txt',
    fileSize: 10,
    fileType: 'text/plain',
    timestamp: DateTime(2025),
  );
}

TransferProgressEntity _progress(String requestId) {
  return TransferProgressEntity(
    requestId: requestId,
    fileName: 'a.txt',
    totalBytes: 100,
    transferredBytes: 20,
    status: TransferStatus.transferring,
    startTime: DateTime.now().subtract(const Duration(seconds: 2)),
  );
}

void main() {
  group('TransferBloc', () {
    test('subscribes to streams and updates state', () async {
      final repo = _FakeTransferRepository();
      final bloc = TransferBloc(
        watchRequestsUsecase: WatchRequestsUsecase(repo),
        watchProgressUsecase: WatchProgressUsecase(repo),
        watchFileSavedUsecase: WatchFileSavedUsecase(repo),
        acceptTransferUsecase: AcceptTransferUsecase(repo),
        denyTransferUsecase: DenyTransferUsecase(repo),
      );

      bloc.add(const TransferStarted());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      repo.requestsController.add([_request('r1')]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.pendingRequests.length, 1);

      repo.progressController.add(_progress('r1'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.activeTransfers.containsKey('r1'), isTrue);
      expect(bloc.state.pendingRequests.where((r) => r.id == 'r1'), isEmpty);

      repo.savedController.add('/tmp/a.txt');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.lastDownloadedPath, '/tmp/a.txt');

      await bloc.close();
      await repo.dispose();
    });

    test('accept and deny all dispatches to repository', () async {
      final repo = _FakeTransferRepository();
      final bloc = TransferBloc(
        watchRequestsUsecase: WatchRequestsUsecase(repo),
        watchProgressUsecase: WatchProgressUsecase(repo),
        watchFileSavedUsecase: WatchFileSavedUsecase(repo),
        acceptTransferUsecase: AcceptTransferUsecase(repo),
        denyTransferUsecase: DenyTransferUsecase(repo),
      );

      bloc.add(const TransferStarted());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      repo.requestsController.add([_request('r1'), _request('r2')]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const TransferAcceptAllRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repo.accepted, ['r1', 'r2']);

      bloc.add(const TransferDenyAllRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repo.denied, ['r1', 'r2']);

      await bloc.close();
      await repo.dispose();
    });
  });
}
