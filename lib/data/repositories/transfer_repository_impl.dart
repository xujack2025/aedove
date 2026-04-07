import '../../domain/entities/transfer_progress_entity.dart';
import '../../domain/entities/transfer_request_entity.dart';
import '../../domain/repositories/transfer_repository.dart';
import '../datasources/transfer/transfer_data_source.dart';

class TransferRepositoryImpl implements TransferRepository {
  const TransferRepositoryImpl(this._dataSource);

  final TransferDataSource _dataSource;

  @override
  Future<void> sendFile({
    required String targetDeviceId,
    required String targetDeviceIP,
    required String filePath,
    required String fileName,
    required int targetDevicePort,
  }) {
    return _dataSource.sendFile(
      targetDeviceId: targetDeviceId,
      targetDeviceIP: targetDeviceIP,
      filePath: filePath,
      fileName: fileName,
      targetDevicePort: targetDevicePort,
    );
  }

  @override
  Stream<List<TransferRequestEntity>> watchRequests() {
    return _dataSource.watchRequests().map(
      (requests) => requests.map((request) => request.toEntity()).toList(),
    );
  }

  @override
  Stream<TransferProgressEntity> watchProgress() {
    return _dataSource.watchProgress().map((progress) => progress.toEntity());
  }

  @override
  Stream<String> watchFileSaved() {
    return _dataSource.watchFileSaved();
  }

  @override
  Future<void> acceptTransfer(String requestId) {
    return _dataSource.acceptTransfer(requestId);
  }

  @override
  Future<void> denyTransfer(String requestId) {
    return _dataSource.denyTransfer(requestId);
  }
}
