import '../../repositories/transfer_repository.dart';

class SendFileUsecase {
  const SendFileUsecase(this._repository);

  final TransferRepository _repository;

  Future<void> call({
    required String targetDeviceId,
    required String targetDeviceIP,
    required String filePath,
    required String fileName,
    required int targetDevicePort,
  }) {
    return _repository.sendFile(
      targetDeviceId: targetDeviceId,
      targetDeviceIP: targetDeviceIP,
      filePath: filePath,
      fileName: fileName,
      targetDevicePort: targetDevicePort,
    );
  }
}
