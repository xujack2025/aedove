import 'package:aedove/domain/entities/device_entity.dart';
import 'package:aedove/presentation/bloc/discovery/discovery_bloc.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:aedove/domain/usecases/transfer/send_file_usecase.dart';
import 'package:aedove/domain/usecases/transfer/validate_selected_files_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:aedove/di/service_locator.dart';
import 'package:aedove/presentation/widgets/send/send_selection_card.dart';
import 'package:aedove/presentation/widgets/send/send_processing_card.dart';
import 'package:aedove/presentation/widgets/send/selected_files_section.dart';
import 'package:aedove/presentation/widgets/send/send_page_header.dart';
import 'package:aedove/presentation/widgets/send/send_devices_section.dart';
import 'package:aedove/presentation/widgets/common/snackbar_helper.dart';
import 'package:aedove/presentation/pages/tabs/send_error_mapper.dart';
import 'package:aedove/presentation/pages/tabs/send_picker_helper.dart';
import 'package:aedove/presentation/pages/tabs/send_picker_ui_state.dart';
import 'package:aedove/presentation/pages/tabs/send_device_transfer_ui_state.dart';

class SendTab extends StatefulWidget {
  const SendTab({super.key});

  @override
  State<SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<SendTab> {
  final SendFileUsecase _sendFileUsecase = sl<SendFileUsecase>();
  final ValidateSelectedFilesUsecase _validateSelectedFilesUsecase =
      sl<ValidateSelectedFilesUsecase>();

  List<File> _selectedFiles = [];
  String _deviceId = '';
  SendPickerUiState _pickerUiState = SendPickerUiState.initial;
  SendDeviceTransferUiState _deviceTransferUiState =
      SendDeviceTransferUiState.initial;

  static const _errorFeedback = _SendFeedbackType.error;
  static const _warningFeedback = _SendFeedbackType.warning;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('device_id') ?? '';
      setState(() {
        _deviceId = id;
      });
    } catch (e) {
      // ignore errors reading prefs
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final paths = SendPickerHelper.platformFilePaths(result.files);
        await _applyValidatedPaths(paths: paths, mediaOnly: false);
      }
    } catch (e) {
      _setLoadingFiles(false);
      _showSendFeedback(
        SendErrorMapper.pickFilesMessage(e),
        type: _errorFeedback,
      );
    }
  }

  Future<void> _pickMedia() async {
    if (_pickerUiState.isPickerActive) {
      return; // Prevent multiple simultaneous picker requests
    }

    _setPickerActive(true);

    try {
      if (_shouldUseAssetPicker) {
        await _pickMediaWithAssetPicker();
      } else {
        await _pickMediaWithFilePicker();
      }
    } catch (e) {
      debugPrint('Unexpected error in _pickMedia: $e');
      _showSendFeedback(
        SendErrorMapper.pickMediaMessage(e),
        type: _errorFeedback,
      );
    } finally {
      _setPickerActive(false);
      _setLoadingFiles(false);
    }
  }

  bool get _shouldUseAssetPicker {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }

  Future<void> _pickMediaWithAssetPicker() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      _showSendFeedback(
        SendErrorMapper.permissionDeniedMessage,
        type: _warningFeedback,
      );
      return;
    }

    if (!mounted) {
      return;
    }

    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 50,
        requestType: RequestType.common,
        textDelegate: EnglishAssetPickerTextDelegate(),
      ),
    );

    debugPrint('📱 Assets picker returned ${assets?.length ?? 0} items');

    if (assets == null || assets.isEmpty) {
      return;
    }

    try {
      final paths = await SendPickerHelper.assetPaths(
        assets,
        onProgress: (message) {
          _setLoadingFiles(true, message: message);
        },
      );

      await _applyValidatedPaths(paths: paths, mediaOnly: true);
    } catch (e) {
      debugPrint('AssetPicker error: $e');
      _showSendFeedback(
        SendErrorMapper.selectMediaMessage(e),
        type: _errorFeedback,
      );
    }
  }

  Future<void> _pickMediaWithFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.media,
      );

      if (result != null && result.files.isNotEmpty) {
        final paths = SendPickerHelper.platformFilePaths(result.files);
        await _applyValidatedPaths(paths: paths, mediaOnly: true);
      }
    } catch (e) {
      debugPrint('FilePicker error: $e');
      _showSendFeedback(
        SendErrorMapper.pickMediaMessage(e),
        type: _errorFeedback,
      );
    }
  }

  Future<void> _applyValidatedPaths({
    required List<String> paths,
    required bool mediaOnly,
  }) async {
    if (paths.isEmpty) {
      return;
    }

    _setLoadingFiles(
      true,
      message: SendPickerHelper.validationMessage(mediaOnly),
    );

    final result = await _validateSelectedFilesUsecase(
      paths: paths,
      mediaOnly: mediaOnly,
    );
    final validFiles = result.files.map((f) => File(f.path)).toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedFiles = validFiles;
    });

    _setLoadingFiles(false);

    if (validFiles.isEmpty && paths.isNotEmpty) {
      _showSendFeedback(
        SendPickerHelper.allRejectedMessage(mediaOnly),
        type: _warningFeedback,
      );
      return;
    }

    if (result.rejectedCount > 0) {
      _showSendFeedback(
        SendErrorMapper.skippedFilesMessage(
          acceptedCount: validFiles.length,
          rejectedCount: result.rejectedCount,
        ),
        type: _warningFeedback,
      );
    }
  }

  void _clearFiles() {
    setState(() {
      _selectedFiles.clear();
    });
  }

  Future<String> _getFileSizeText(File file) async {
    try {
      // Check if it's a directory
      final stat = await FileStat.stat(file.path);
      if (stat.type == FileSystemEntityType.directory) {
        return 'Package';
      }

      final length = await file.length();
      final sizeMB = (length / 1024 / 1024).toStringAsFixed(2);
      return '$sizeMB MB';
    } catch (e) {
      debugPrint('Error getting file size for ${file.path}: $e');
      return 'Unknown size';
    }
  }

  Future<void> _sendFilesToDevice(DeviceEntity device) async {
    if (!_canSendFiles()) {
      return;
    }

    _updateDeviceTransferState(device.id, sending: true);

    try {
      await _sendSelectedFiles(device);
      await _showSendSuccessState(device.id);
    } catch (e) {
      _handleSendFailure(device.id, e);
    }
  }

  bool _canSendFiles() {
    if (_selectedFiles.isNotEmpty) {
      return true;
    }

    _showSendFeedback(
      SendErrorMapper.noFilesSelectedMessage,
      type: _warningFeedback,
    );
    return false;
  }

  Future<void> _sendSelectedFiles(DeviceEntity device) async {
    for (final file in _selectedFiles) {
      await _sendFileUsecase(
        targetDeviceId: device.id,
        targetDeviceIP: device.ip,
        filePath: file.path,
        fileName: p.basename(file.path),
        targetDevicePort: device.port,
      );
    }
  }

  Future<void> _showSendSuccessState(String deviceId) async {
    _updateDeviceTransferState(
      deviceId,
      sending: false,
      sentSuccessfully: true,
    );
    await Future.delayed(const Duration(seconds: 2));
    _updateDeviceTransferState(deviceId, sentSuccessfully: false);
  }

  void _handleSendFailure(String deviceId, Object error) {
    _showSendFeedback(
      SendErrorMapper.sendFilesMessage(error),
      type: _errorFeedback,
    );
    _updateDeviceTransferState(deviceId, sending: false);
  }

  void _showSendFeedback(String message, {required _SendFeedbackType type}) {
    switch (type) {
      case _SendFeedbackType.error:
        SnackBarHelper.showError(context, message);
      case _SendFeedbackType.warning:
        SnackBarHelper.showWarning(context, message);
    }
  }

  void _setPickerUiState(SendPickerUiState nextState) {
    if (!mounted) {
      return;
    }

    setState(() {
      _pickerUiState = nextState;
    });
  }

  void _setPickerActive(bool active) {
    _setPickerUiState(_pickerUiState.copyWith(isPickerActive: active));
  }

  void _setLoadingFiles(bool loading, {String? message}) {
    _setPickerUiState(
      _pickerUiState.copyWith(isLoadingFiles: loading, loadingMessage: message),
    );
  }

  void _setDeviceTransferUiState(SendDeviceTransferUiState nextState) {
    if (!mounted) {
      return;
    }

    setState(() {
      _deviceTransferUiState = nextState;
    });
  }

  void _updateDeviceTransferState(
    String deviceId, {
    bool? sending,
    bool? sentSuccessfully,
  }) {
    var nextState = _deviceTransferUiState;

    if (sending != null) {
      nextState = nextState.withSending(deviceId, sending);
    }

    if (sentSuccessfully != null) {
      nextState = nextState.withSentSuccessfully(deviceId, sentSuccessfully);
    }

    _setDeviceTransferUiState(nextState);
  }

  @override
  Widget build(BuildContext context) {
    final discoveryState = context.watch<DiscoveryBloc>().state;
    final discoveredDevices = discoveryState.devices
        .where((d) => d.id != _deviceId)
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 24.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const SendPageHeader(),
          const SizedBox(height: 24),

          // File Selection
          if (Platform.isAndroid || Platform.isIOS) ...[
            Row(
              children: [
                Expanded(
                  child: SendSelectionCard(
                    icon: Icons.folder_open_rounded,
                    label: 'Files',
                    color: Colors.blue,
                    onTap: _pickFiles,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SendSelectionCard(
                    icon: Icons.photo_library_rounded,
                    label: 'Media',
                    color: Colors.purple,
                    onTap: _pickMedia,
                  ),
                ),
              ],
            ),
          ] else ...[
            SendSelectionCard(
              icon: Icons.folder_open_rounded,
              label: 'Select Files',
              color: Colors.blue,
              onTap: _pickFiles,
            ),
          ],

          const SizedBox(height: 32),

          // Loading indicator when processing files
          if (_pickerUiState.isLoadingFiles) ...[
            SendProcessingCard(message: _pickerUiState.loadingMessage),
            const SizedBox(height: 32),
          ],

          // Selected Files
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: SelectedFilesSection(
              files: _selectedFiles,
              onClear: _clearFiles,
              getFileSizeText: _getFileSizeText,
            ),
          ),

          const SizedBox(height: 24),

          // Discovered Devices
          Text(
            'Nearby Devices',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          SendDevicesSection(
            devices: discoveredDevices,
            hasSelectedFiles: _selectedFiles.isNotEmpty,
            deviceTransferUiState: _deviceTransferUiState,
            onSendTap: _sendFilesToDevice,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

enum _SendFeedbackType { error, warning }
