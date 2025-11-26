import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aedove/services/device_discovery_service.dart';
import 'package:aedove/services/file_transfer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

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
    if (_isPickerActive) {
      return; // Prevent multiple simultaneous picker requests
    }

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
          fileName: p.basename(file.path),
          targetDevicePort: device.port,
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
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selection',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
              ],
            ),

            // File Selection
            if (Platform.isAndroid || Platform.isIOS) ...[
              Row(
                children: [
                  // File selection buttons
                  SizedBox(
                    width: 84,
                    height: 72,
                    child: ElevatedButton(
                      onPressed: _pickFiles,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open, size: 32),
                          const SizedBox(height: 4),
                          Text('Files'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Media selection button
                  SizedBox(
                    width: 84,
                    height: 72,
                    child: ElevatedButton(
                      onPressed: _pickMedia,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library, size: 32),
                          const SizedBox(height: 4),
                          Text('Media'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  SizedBox(
                    width: 84,
                    height: 72,
                    child: ElevatedButton(
                      onPressed: _pickFiles,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open, size: 32),
                          const SizedBox(height: 4),
                          Text('Files'),
                        ],
                      ),
                    ),
                  ),
                ],
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
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedFiles.length,
                          itemBuilder: (context, index) {
                            final file = _selectedFiles[index];
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.2),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.insert_drive_file,
                                    size: 32,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    p.basename(file.path),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
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
              Padding(
                padding: const EdgeInsets.all(0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Devices (${_discoveredDevices.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = _discoveredDevices[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.devices),
                            title: Text(device.name),
                            subtitle: Text('${device.ip}:${device.port}'),
                            trailing: _selectedFiles.isNotEmpty
                                ? ElevatedButton.icon(
                                    onPressed:
                                        (_sendingByDeviceId[device.id] ?? false)
                                        ? null
                                        : () => _sendFilesToDevice(device),
                                    icon:
                                        (_sendingByDeviceId[device.id] ?? false)
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.send),
                                    label: Text(
                                      (_sendingByDeviceId[device.id] ?? false)
                                          ? 'Sending...'
                                          : 'Send',
                                    ),
                                  )
                                : const Icon(Icons.wifi, color: Colors.green),
                          ),
                        );
                      },
                    ),
                  ],
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
                        'Make sure other devices are connected to the same WiFi network and have Aedove running',
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
