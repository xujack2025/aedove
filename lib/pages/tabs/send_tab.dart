import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cpshare/services/device_discovery_service.dart';
import 'package:cpshare/services/file_transfer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SendTab extends StatefulWidget {
  const SendTab({super.key});

  @override
  State<SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<SendTab> {
  List<File> _selectedFiles = [];
  List<DeviceInfo> _discoveredDevices = [];
  final Map<String, bool> _sendingByDeviceId = {};
  String _deviceId = '';
  bool _isPickerActive = false; // Track if a picker is currently active

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
    _setupStreams();
  }

  void _setupStreams() {
    // Listen to device discovery stream
    DeviceDiscoveryService.devicesStream.listen((devices) {
      final filtered = _deviceId.isNotEmpty
          ? devices.where((d) => d.id != _deviceId).toList()
          : devices;
      if (mounted) {
        setState(() {
          _discoveredDevices = filtered;
        });
      }
    });
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          _selectedFiles = result.paths.map((path) => File(path!)).toList();
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking files: $e');
    }
  }

  Future<void> _pickMedia() async {
    if (_isPickerActive)
      return; // Prevent multiple simultaneous picker requests

    try {
      setState(() {
        _isPickerActive = true;
      });

      // Use ImagePicker for media selection
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final picker = ImagePicker();

        // Show a dialog to choose between images and videos
        final choice = await showDialog<String>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Select Media Type'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo),
                  title: const Text('Photos'),
                  onTap: () => Navigator.pop(context, 'photos'),
                ),
                ListTile(
                  leading: const Icon(Icons.video_library),
                  title: const Text('Videos'),
                  onTap: () => Navigator.pop(context, 'videos'),
                ),
                ListTile(
                  leading: const Icon(Icons.perm_media),
                  title: const Text('All Media'),
                  onTap: () => Navigator.pop(context, 'all'),
                ),
              ],
            ),
          ),
        );

        if (choice == null) {
          setState(() {
            _isPickerActive = false;
          });
          return;
        }

        List<XFile> selectedMedia = [];

        try {
          switch (choice) {
            case 'photos':
              selectedMedia = await picker.pickMultiImage();
              break;
            case 'videos':
              selectedMedia = await picker
                  .pickVideo(source: ImageSource.gallery)
                  .then((video) => video != null ? [video] : []);
              break;
            case 'all':
              selectedMedia = await picker.pickMultipleMedia();
              break;
          }

          if (selectedMedia.isNotEmpty) {
            setState(() {
              _selectedFiles = selectedMedia
                  .where((x) => x.path.isNotEmpty)
                  .map((x) => File(x.path))
                  .toList();
            });
          }
        } finally {
          setState(() {
            _isPickerActive = false;
          });
          return;
        }
      }

      // Fallback: generic file picker filtered to media
      try {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.media,
        );
        if (result != null) {
          setState(() {
            _selectedFiles = result.paths
                .whereType<String>()
                .map((p) => File(p))
                .toList();
          });
        }
      } finally {
        // Make sure we reset the picker state even if FilePicker was cancelled
        setState(() {
          _isPickerActive = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking media: $e');
    } finally {
      setState(() {
        _isPickerActive = false;
      });
    }
  }

  void _clearFiles() {
    setState(() {
      _selectedFiles.clear();
    });
  }

  Future<void> _sendFilesToDevice(DeviceInfo device) async {
    if (_selectedFiles.isEmpty) {
      _showErrorSnackBar('Please select files to send');
      return;
    }

    setState(() {
      _sendingByDeviceId[device.id] = true;
    });

    try {
      for (final file in _selectedFiles) {
        await FileTransferService.sendFile(
          targetDeviceId: device.id,
          targetDeviceIP: device.ip,
          filePath: file.path,
          fileName: file.path.split('/').last,
        );
      }

      _showSuccessSnackBar('Files sent successfully to ${device.name}!');
    } catch (e) {
      _showErrorSnackBar('Error sending files: $e');
    } finally {
      setState(() {
        _sendingByDeviceId[device.id] = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.send,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Send Files',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // File Selection
            if (Platform.isAndroid || Platform.isIOS) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Select Files'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickMedia,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Select Media'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select Files'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Selected Files
            if (_selectedFiles.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Selected Files (${_selectedFiles.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            onPressed: _clearFiles,
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear all files',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          itemCount: _selectedFiles.length,
                          itemBuilder: (context, index) {
                            final file = _selectedFiles[index];
                            return ListTile(
                              leading: const Icon(Icons.insert_drive_file),
                              title: Text(
                                file.path.split('/').last,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Discovered Devices
            if (_discoveredDevices.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Devices (${_discoveredDevices.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: _discoveredDevices.length,
                          itemBuilder: (context, index) {
                            final device = _discoveredDevices[index];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.device_hub),
                                title: Text(device.name),
                                subtitle: Text('${device.ip}:${device.port}'),
                                trailing: _selectedFiles.isNotEmpty
                                    ? ElevatedButton.icon(
                                        onPressed:
                                            (_sendingByDeviceId[device.id] ??
                                                false)
                                            ? null
                                            : () => _sendFilesToDevice(device),
                                        icon:
                                            (_sendingByDeviceId[device.id] ??
                                                false)
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.send),
                                        label: Text(
                                          (_sendingByDeviceId[device.id] ??
                                                  false)
                                              ? 'Sending...'
                                              : 'Send',
                                        ),
                                      )
                                    : const Icon(
                                        Icons.wifi,
                                        color: Colors.green,
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // No devices discovered
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.device_hub, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No devices found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Make sure other devices are connected to the same WiFi network and have CPS Share running',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // No files selected
            if (_selectedFiles.isEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_upload,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No files selected',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "Select Files" or "Select Media" to choose items to send',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
