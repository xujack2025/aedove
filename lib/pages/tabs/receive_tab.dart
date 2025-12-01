import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:aedove/services/device_discovery_service.dart';
import 'package:aedove/services/file_transfer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aedove/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:open_file/open_file.dart';

class ReceiveTab extends StatefulWidget {
  const ReceiveTab({super.key});

  @override
  State<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<ReceiveTab>
    with SingleTickerProviderStateMixin {
  String _deviceName = 'My Device';
  // ignore: unused_field
  String _deviceId = '';
  String _ipAddress = 'Unknown';
  // List<DeviceInfo> _discoveredDevices = []; // removed, no longer shown
  List<FileTransferRequest> _pendingRequests = [];
  bool _permissionsPromptShown = false;
  String _lastDownloadedPath = '';
  final Map<String, FileTransferProgress> _activeTransfers = {};

  // Animation for the "Listening" pulse effect
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
    _setupStreams();
  }

  void _setupStreams() {
    // Listen to device discovery stream
    // No UI usage for discovered devices on Receive tab anymore; keep listener empty to retain service.
    DeviceDiscoveryService.devicesStream.listen((_) {});

    // Listen to file transfer requests stream
    FileTransferService.requestsStream.listen((requests) {
      if (mounted) {
        setState(() {
          _pendingRequests = requests;
        });
      }
    });

    // Listen for file saved events so we can show the path in the UI
    FileTransferService.fileSavedStream.listen((path) {
      if (mounted) {
        setState(() {
          _lastDownloadedPath = path;
        });
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File saved to: $path'),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } catch (e) {
          // ignore if scaffold not ready
        }
      }
    });

    // Listen to file transfer progress updates
    FileTransferService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          if (progress.status == TransferStatus.completed ||
              progress.status == TransferStatus.failed) {
            // Remove from active transfers after completion/failure
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _activeTransfers.remove(progress.requestId);
                });
              }
            });
          } else {
            _activeTransfers[progress.requestId] = progress;
          }
        });
      }
    });
  }

  Future<void> _getDeviceInfo() async {
    try {
      if (Platform.isWindows) {
        // On Windows, we need to find the IP address differently
        try {
          final interfaces = await NetworkInterface.list(
            includeLinkLocal: false,
            type: InternetAddressType.IPv4,
          );

          // Find the first non-loopback IPv4 address
          for (var interface in interfaces) {
            for (var addr in interface.addresses) {
              if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
                setState(() {
                  _ipAddress = addr.address;
                });
                return;
              }
            }
          }
        } catch (e) {
          debugPrint('Error getting Windows IP: $e');
        }
      } else {
        // For other platforms, use network_info_plus
        final networkInfo = NetworkInfo();
        final connectivityResult = await Connectivity().checkConnectivity();

        if (connectivityResult.isNotEmpty &&
            connectivityResult.first != ConnectivityResult.none) {
          final wifiIP = await networkInfo.getWifiIP();
          setState(() {
            _ipAddress = wifiIP ?? 'Unknown';
          });
        }
      }
      // Try to read the stored device name (set elsewhere in the app)
      try {
        final prefs = await SharedPreferences.getInstance();
        final storedName = prefs.getString('device_name');
        final storedId = prefs.getString('device_id');
        if (storedId != null && storedId.isNotEmpty) {
          _deviceId = storedId;
        }
        if (storedName != null && storedName.isNotEmpty) {
          setState(() {
            _deviceName = storedName;
          });
        }
      } catch (e) {
        debugPrint('Error reading device name from prefs: $e');
      }
      // Ensure required runtime permissions are requested and show a
      // user-facing prompt if denied so the warnings stop appearing.
      await _ensurePermissions();
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
  }

  Future<void> _ensurePermissions() async {
    // Desktop platforms (Windows, macOS, Linux) and iOS handle permissions differently
    if (Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isIOS) {
      return;
    }

    try {
      // Check current permission status before requesting
      final storageStatus = Platform.isAndroid
          ? await ph.Permission.storage.status
          : ph.PermissionStatus.granted;
      final locationStatus = Platform.isAndroid
          ? await ph.Permission.location.status
          : ph.PermissionStatus.granted;

      // If both permissions are already granted or limited (limited access is acceptable), don't show any dialog
      if ((storageStatus.isGranted || storageStatus.isLimited) &&
          (locationStatus.isGranted || locationStatus.isLimited)) {
        return;
      }

      // Request permissions
      final storageGranted = await PermissionService.requestStoragePermission();
      final locationGranted =
          await PermissionService.requestLocationPermission();

      // If permissions are now granted, don't show the dialog
      if (storageGranted && locationGranted) return;

      // If we've already shown the prompt, don't spam the user.
      if (_permissionsPromptShown) return;
      _permissionsPromptShown = true;

      // Show a dialog giving the user options to retry or open app settings.
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Permissions required'),
              content: const Text(
                'Storage and/or location permissions are required for receiving files and discovering devices.\n\n'
                'You can retry granting permissions or open app settings to enable them.',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    _permissionsPromptShown = false;
                    await _ensurePermissions();
                  },
                  child: const Text('Retry'),
                ),
                if (Platform.isAndroid ||
                    Platform
                        .isIOS) // Only show Open Settings on mobile platforms
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      // Open OS app settings page
                      await ph.openAppSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Ignore'),
                ),
              ],
            );
          },
        );
      });
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 24.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Modern Status Card with pulse animation
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withValues(alpha: 0.1),
                  primaryColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: primaryColor.withAlpha((0.2 * 255).round()),
              ),
            ),
            child: Row(
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.wifi_tethering,
                      size: 32,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _deviceName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.link, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _ipAddress,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[700],
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Pending File Transfer Requests
          if (_pendingRequests.isNotEmpty) ...[
            // 1. The Header Row
            Row(
              children: [
                // FLEXIBLE TITLE: Takes up remaining space
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        // Prevents text overflow
                        child: Text(
                          'Incoming Requests',
                          overflow: TextOverflow
                              .ellipsis, // Adds ... if text is too long
                          maxLines: 1,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_pendingRequests.length}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // BULK ACTIONS (Only show if > 1)
                if (_pendingRequests.length > 1) ...[
                  const SizedBox(width: 8),
                  // Accept Button -> Compact Filled Button
                  FilledButton.icon(
                    onPressed: _acceptAllFiles,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green, // Distinct positive action
                      foregroundColor: Colors.white,
                      visualDensity:
                          VisualDensity.compact, // Reduces vertical height
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text(
                      "Accept All",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Decline Button -> Converted to Icon to save space
                  IconButton(
                    onPressed: _denyAllFiles,
                    tooltip: "Decline All",
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red[300],
                      size: 22,
                    ),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pendingRequests.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final request = _pendingRequests[index];
                  return _buildRequestCard(request, theme);
                },
              ),
            ),
          ] else ...[
            // Empty State
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.move_to_inbox_rounded,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting for files...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask the sender to select your device',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Active file transfers
          if (_activeTransfers.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Downloading',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_activeTransfers.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activeTransfers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final progress = _activeTransfers.values.elementAt(index);
                return _buildProgressCard(progress, theme);
              },
            ),
            const SizedBox(height: 24),
          ],

          // Last downloaded file path
          if (_lastDownloadedPath.isNotEmpty)
            InkWell(
              onTap: () => _openFile(_lastDownloadedPath),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last Received',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            _lastDownloadedPath.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.open_in_new, size: 18, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),

          // Auto-receive toggle
          // Card(
          //   child: SwitchListTile(
          //     title: const Text('Auto-receive files'),
          //     subtitle: const Text(
          //       'Automatically accept files from trusted devices',
          //     ),
          //     value: _isReceiving,
          //     onChanged: (value) {
          //       setState(() {
          //         _isReceiving = value;
          //       });
          //     },
          //   ),
          // ),
        ],
      ),
    );
  }

  // Progress card for active transfers
  Widget _buildProgressCard(FileTransferProgress progress, ThemeData theme) {
    final Color statusColor = progress.status == TransferStatus.completed
        ? Colors.green
        : progress.status == TransferStatus.failed
        ? Colors.red
        : Colors.blue;

    final IconData statusIcon = progress.status == TransferStatus.completed
        ? Icons.check_circle
        : progress.status == TransferStatus.failed
        ? Icons.error
        : Icons.downloading;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.fileName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatFileSize(progress.totalBytes),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (progress.status == TransferStatus.transferring)
                Text(
                  progress.progressPercent,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
            ],
          ),
          if (progress.status == TransferStatus.transferring) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.progress,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatFileSize(progress.transferredBytes)} of ${_formatFileSize(progress.totalBytes)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                if (progress.estimatedTimeRemaining != null)
                  Text(
                    _formatDuration(progress.estimatedTimeRemaining!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
          if (progress.status == TransferStatus.completed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Transfer complete!',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (progress.status == TransferStatus.failed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Transfer failed: ${progress.errorMessage ?? "Unknown error"}',
                style: TextStyle(color: Colors.red[700], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  // File transfer request card
  Widget _buildRequestCard(FileTransferRequest request, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getFileIcon(request.fileType),
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.fileName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatFileSize(request.fileSize)} • from ${request.senderName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 48, // Matches your divider height
            child: Row(
              // This is the key: Force children to fill the vertical space
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _denyFileTransfer(request.id),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Decline'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      // Remove vertical padding so the button content centers automatically
                      // within the stretched height
                      padding: EdgeInsets.zero,
                      // Optional: Removes default margin around the button touch target
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
                // Use VerticalDivider instead of Container for cleaner code inside a Row
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Colors.grey[400],
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _acceptFileTransfer(request.id),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                      padding: EdgeInsets.zero, // Remove vertical padding
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    if (fileType.contains('image')) return Icons.image;
    if (fileType.contains('video')) return Icons.movie;
    if (fileType.contains('audio')) return Icons.audiotrack;
    if (fileType.contains('pdf')) return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  void _acceptFileTransfer(String requestId) {
    FileTransferService.acceptFileTransfer(requestId);
    setState(() {
      _pendingRequests.removeWhere((request) => request.id == requestId);
    });
    if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(
    //     content: Text('File transfer accepted'),
    //     backgroundColor: Colors.green,
    //   ),
    // );
  }

  void _denyFileTransfer(String requestId) {
    FileTransferService.denyFileTransfer(requestId);
    setState(() {
      _pendingRequests.removeWhere((request) => request.id == requestId);
    });
    if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(
    //     content: Text('File transfer denied'),
    //     backgroundColor: Colors.red,
    //   ),
    // );
  }

  void _acceptAllFiles() {
    final requestIds = _pendingRequests.map((r) => r.id).toList();
    for (final requestId in requestIds) {
      FileTransferService.acceptFileTransfer(requestId);
    }
    setState(() {
      _pendingRequests.clear();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Accepting ${requestIds.length} files...'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _denyAllFiles() {
    final requestIds = _pendingRequests.map((r) => r.id).toList();
    for (final requestId in requestIds) {
      FileTransferService.denyFileTransfer(requestId);
    }
    setState(() {
      _pendingRequests.clear();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Declined ${requestIds.length} files'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      // Check if it's a gallery marker (from our MediaStoreService)
      if (filePath.startsWith('gallery://')) {
        final fileName = filePath.replaceFirst('gallery://', '');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$fileName saved to gallery. Open your Photos/Gallery app to view.',
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Check if it's a content URI or gallery path
      if (filePath.startsWith('content://') ||
          filePath.contains('DCIM') ||
          filePath.contains('Pictures') ||
          filePath.contains('Movies')) {
        _showOpenError(
          'File saved to gallery. Open your Photos/Gallery app to view.',
        );
        return;
      }

      // Try opening with OpenFile for regular files
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done && mounted) {
        _showOpenError('Could not open file: ${result.message}');
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      _showOpenError('Error opening file: $e');
    }
  }

  void _showOpenError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.orange),
      );
    }
  }
}
