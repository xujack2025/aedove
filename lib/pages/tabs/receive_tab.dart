import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:cpshare/services/device_discovery_service.dart';
import 'package:cpshare/services/file_transfer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cpshare/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class ReceiveTab extends StatefulWidget {
  const ReceiveTab({super.key});

  @override
  State<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<ReceiveTab> {
  bool _isReceiving = false;
  String _deviceName = 'My Device';
  // ignore: unused_field
  String _deviceId = '';
  String _ipAddress = 'Unknown';
  // List<DeviceInfo> _discoveredDevices = []; // removed, no longer shown
  List<FileTransferRequest> _pendingRequests = [];
  bool _permissionsPromptShown = false;
  String _lastDownloadedPath = '';

  @override
  void initState() {
    super.initState();
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
            ),
          );
        } catch (e) {
          // ignore if scaffold not ready
        }
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
        Platform.isIOS)
      return;

    try {
      final storageGranted = await PermissionService.requestStoragePermission();
      final locationGranted =
          await PermissionService.requestLocationPermission();

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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Device Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.wifi,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ready to Receive',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Device: $_deviceName',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'IP Address: $_ipAddress',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Pending File Transfer Requests
            if (_pendingRequests.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending File Transfers (${_pendingRequests.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _pendingRequests.length,
                        itemBuilder: (context, index) {
                          final request = _pendingRequests[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.file_present),
                              title: Text(request.fileName),
                              subtitle: Text(
                                'From: ${request.senderName}\n'
                                'Size: ${_formatFileSize(request.fileSize)}\n'
                                'Type: ${request.fileType}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        _acceptFileTransfer(request.id),
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.green,
                                    ),
                                    tooltip: 'Accept',
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _denyFileTransfer(request.id),
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Deny',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Last downloaded file path
            if (_lastDownloadedPath.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.download_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Last downloaded: $_lastDownloadedPath',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

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
      ),
    );
  }

  void _acceptFileTransfer(String requestId) {
    FileTransferService.acceptFileTransfer(requestId);
    setState(() {
      _pendingRequests.removeWhere((request) => request.id == requestId);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File transfer accepted'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _denyFileTransfer(String requestId) {
    FileTransferService.denyFileTransfer(requestId);
    setState(() {
      _pendingRequests.removeWhere((request) => request.id == requestId);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File transfer denied'),
        backgroundColor: Colors.red,
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
}
