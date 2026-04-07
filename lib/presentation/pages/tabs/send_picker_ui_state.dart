class SendPickerUiState {
  const SendPickerUiState({
    required this.isPickerActive,
    required this.isLoadingFiles,
    required this.loadingMessage,
  });

  static const SendPickerUiState initial = SendPickerUiState(
    isPickerActive: false,
    isLoadingFiles: false,
    loadingMessage: 'Processing files...',
  );

  final bool isPickerActive;
  final bool isLoadingFiles;
  final String loadingMessage;

  SendPickerUiState copyWith({
    bool? isPickerActive,
    bool? isLoadingFiles,
    String? loadingMessage,
  }) {
    return SendPickerUiState(
      isPickerActive: isPickerActive ?? this.isPickerActive,
      isLoadingFiles: isLoadingFiles ?? this.isLoadingFiles,
      loadingMessage: loadingMessage ?? this.loadingMessage,
    );
  }
}
