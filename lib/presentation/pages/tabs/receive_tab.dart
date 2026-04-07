import 'package:aedove/domain/usecases/device_info/get_local_ip_address_usecase.dart';
import 'package:aedove/domain/usecases/file_access/open_file_usecase.dart';
import 'package:aedove/domain/usecases/file_access/show_in_file_manager_usecase.dart';
import 'package:aedove/presentation/bloc/transfer/transfer_bloc.dart';
import 'package:aedove/presentation/bloc/transfer/transfer_event.dart';
import 'package:aedove/presentation/bloc/transfer/transfer_state.dart';
import 'package:aedove/presentation/widgets/common/snackbar_helper.dart';
import 'package:aedove/presentation/pages/tabs/receive_error_mapper.dart';
import 'package:aedove/presentation/widgets/receive/receive_empty_state_card.dart';
import 'package:aedove/presentation/widgets/receive/receive_downloading_section.dart';
import 'package:aedove/presentation/widgets/receive/receive_last_downloaded_card.dart';
import 'package:aedove/presentation/widgets/receive/receive_file_path_helper.dart';
import 'package:aedove/presentation/widgets/receive/receive_open_file_dialog.dart';
import 'package:aedove/presentation/widgets/receive/receive_requests_section.dart';
import 'package:aedove/presentation/widgets/receive/receive_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aedove/di/service_locator.dart';

class ReceiveTab extends StatefulWidget {
  const ReceiveTab({super.key});

  @override
  State<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<ReceiveTab>
    with SingleTickerProviderStateMixin {
  final GetLocalIpAddressUsecase _getLocalIpAddressUsecase =
      sl<GetLocalIpAddressUsecase>();
  final OpenFileUsecase _openFileUsecase = sl<OpenFileUsecase>();
  final ShowInFileManagerUsecase _showInFileManagerUsecase =
      sl<ShowInFileManagerUsecase>();

  String _deviceName = 'My Device';
  String _ipAddress = 'Unknown';

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  static const _infoFeedback = _ReceiveFeedbackType.info;
  static const _warningFeedback = _ReceiveFeedbackType.warning;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _getDeviceInfo();
  }

  Future<void> _getDeviceInfo() async {
    try {
      final ipAddress = await _getLocalIpAddressUsecase();
      if (mounted) {
        setState(() => _ipAddress = ipAddress);
      }

      final prefs = await SharedPreferences.getInstance();
      if (!mounted) {
        return;
      }

      final storedName = prefs.getString('device_name');
      if (storedName != null && storedName.isNotEmpty) {
        setState(() => _deviceName = storedName);
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transferState = context.watch<TransferBloc>().state;

    return BlocListener<TransferBloc, TransferState>(
      listenWhen: (previous, current) =>
          previous.lastDownloadedPath != current.lastDownloadedPath &&
          current.lastDownloadedPath.isNotEmpty,
      listener: (context, state) {
        _showReceiveFeedback(
          'File saved to: ${state.lastDownloadedPath}',
          type: _infoFeedback,
        );
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 24.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            ReceiveStatusCard(
              deviceName: _deviceName,
              ipAddress: _ipAddress,
              pulseAnimation: _pulseAnimation,
            ),
            const SizedBox(height: 24),
            if (transferState.pendingRequests.isNotEmpty) ...[
              ReceiveRequestsSection(
                requests: transferState.pendingRequests,
                onAcceptRequest: _acceptFileTransfer,
                onDenyRequest: _denyFileTransfer,
                onAcceptAll: _acceptAllFiles,
                onDenyAll: _denyAllFiles,
              ),
            ] else ...[
              ReceiveEmptyStateCard(
                title: 'Waiting for files...',
                subtitle: 'Ask the sender to select your device',
              ),
            ],
            const SizedBox(height: 24),
            if (transferState.activeTransfers.isNotEmpty) ...[
              ReceiveDownloadingSection(
                progressItems: transferState.activeTransfers.values.toList(),
              ),
              const SizedBox(height: 24),
            ],
            if (transferState.lastDownloadedPath.isNotEmpty)
              ReceiveLastDownloadedCard(
                filePath: transferState.lastDownloadedPath,
                onTap: () => _openFile(transferState.lastDownloadedPath),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _acceptFileTransfer(String requestId) {
    context.read<TransferBloc>().add(TransferAcceptRequested(requestId));
  }

  void _denyFileTransfer(String requestId) {
    context.read<TransferBloc>().add(TransferDenyRequested(requestId));
  }

  void _acceptAllFiles() {
    context.read<TransferBloc>().add(const TransferAcceptAllRequested());
  }

  void _denyAllFiles() {
    context.read<TransferBloc>().add(const TransferDenyAllRequested());
  }

  Future<void> _openFile(String filePath) async {
    try {
      if (ReceiveFilePathHelper.isExplicitGallerySavedPath(filePath)) {
        if (mounted) {
          _showReceiveFeedback(
            ReceiveErrorMapper.savedToGalleryMessage(
              ReceiveFilePathHelper.gallerySavedFileName(filePath),
            ),
            type: _infoFeedback,
          );
        }
        return;
      }

      if (ReceiveFilePathHelper.isGalleryPath(filePath)) {
        _showOpenError(ReceiveErrorMapper.gallerySavedHint);
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) {
            return ReceiveOpenFileDialog(
              onShowInFolder: () async {
                final success = await _showInFileManagerUsecase(filePath);
                if (!success && mounted) {
                  _showReceiveFeedback(
                    ReceiveErrorMapper.openFileManagerFailure(),
                    type: _warningFeedback,
                  );
                }
              },
              onOpenFile: () async {
                final success = await _openFileUsecase(filePath);
                if (!success && mounted) {
                  _showReceiveFeedback(
                    ReceiveErrorMapper.openFileFailure(),
                    type: _warningFeedback,
                  );
                }
              },
            );
          },
        );
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      _showOpenError(ReceiveErrorMapper.openFileError(e));
    }
  }

  void _showOpenError(String message) {
    if (mounted) {
      _showReceiveFeedback(message, type: _warningFeedback);
    }
  }

  void _showReceiveFeedback(
    String message, {
    required _ReceiveFeedbackType type,
  }) {
    switch (type) {
      case _ReceiveFeedbackType.info:
        SnackBarHelper.showInfo(context, message);
      case _ReceiveFeedbackType.warning:
        SnackBarHelper.showWarning(context, message);
    }
  }
}

enum _ReceiveFeedbackType { info, warning }
