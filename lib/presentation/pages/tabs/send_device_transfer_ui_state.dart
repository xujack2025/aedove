class SendDeviceTransferUiState {
  const SendDeviceTransferUiState({
    required this.sendingByDeviceId,
    required this.sentSuccessfullyByDeviceId,
  });

  static const SendDeviceTransferUiState initial = SendDeviceTransferUiState(
    sendingByDeviceId: <String, bool>{},
    sentSuccessfullyByDeviceId: <String, bool>{},
  );

  final Map<String, bool> sendingByDeviceId;
  final Map<String, bool> sentSuccessfullyByDeviceId;

  bool isSending(String deviceId) => sendingByDeviceId[deviceId] ?? false;

  bool isSentSuccessfully(String deviceId) {
    return sentSuccessfullyByDeviceId[deviceId] ?? false;
  }

  SendDeviceTransferUiState copyWith({
    Map<String, bool>? sendingByDeviceId,
    Map<String, bool>? sentSuccessfullyByDeviceId,
  }) {
    return SendDeviceTransferUiState(
      sendingByDeviceId: sendingByDeviceId ?? this.sendingByDeviceId,
      sentSuccessfullyByDeviceId:
          sentSuccessfullyByDeviceId ?? this.sentSuccessfullyByDeviceId,
    );
  }

  SendDeviceTransferUiState withSending(String deviceId, bool sending) {
    final nextSending = Map<String, bool>.from(sendingByDeviceId)
      ..[deviceId] = sending;
    return copyWith(sendingByDeviceId: nextSending);
  }

  SendDeviceTransferUiState withSentSuccessfully(
    String deviceId,
    bool sentSuccessfully,
  ) {
    final nextSuccess = Map<String, bool>.from(sentSuccessfullyByDeviceId)
      ..[deviceId] = sentSuccessfully;
    return copyWith(sentSuccessfullyByDeviceId: nextSuccess);
  }
}
