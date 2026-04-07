import 'package:aedove/presentation/pages/tabs/send_device_transfer_ui_state.dart';
import 'package:aedove/presentation/pages/tabs/send_picker_ui_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SendPickerUiState', () {
    test('copyWith preserves existing values when omitted', () {
      const state = SendPickerUiState(
        isPickerActive: true,
        isLoadingFiles: false,
        loadingMessage: 'Processing files...',
      );

      final nextState = state.copyWith(isLoadingFiles: true);

      expect(nextState.isPickerActive, isTrue);
      expect(nextState.isLoadingFiles, isTrue);
      expect(nextState.loadingMessage, 'Processing files...');
    });

    test('initial state has expected defaults', () {
      expect(SendPickerUiState.initial.isPickerActive, isFalse);
      expect(SendPickerUiState.initial.isLoadingFiles, isFalse);
      expect(SendPickerUiState.initial.loadingMessage, 'Processing files...');
    });
  });

  group('SendDeviceTransferUiState', () {
    test('tracks sending and success states by device id', () {
      final state = SendDeviceTransferUiState.initial
          .withSending('device-1', true)
          .withSentSuccessfully('device-1', true)
          .withSending('device-2', false);

      expect(state.isSending('device-1'), isTrue);
      expect(state.isSentSuccessfully('device-1'), isTrue);
      expect(state.isSending('device-2'), isFalse);
      expect(state.isSentSuccessfully('device-2'), isFalse);
    });

    test('copyWith keeps existing maps unless replaced', () {
      final state = SendDeviceTransferUiState.initial.withSending(
        'device-1',
        true,
      );

      final nextState = state.copyWith(
        sentSuccessfullyByDeviceId: {'device-1': true},
      );

      expect(nextState.isSending('device-1'), isTrue);
      expect(nextState.isSentSuccessfully('device-1'), isTrue);
    });
  });
}
