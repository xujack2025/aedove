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

  Widget _buildSelectionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      elevation: 2,
      shadowColor: Colors.black.withAlpha((0.1 * 255).round()),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 140,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha((0.1 * 255).round()),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 24.0),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Send Files',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select files or media to share with nearby devices',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
              ),
            ),
            const SizedBox(height: 24),

            // File Selection
            if (Platform.isAndroid || Platform.isIOS) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildSelectionCard(
                      icon: Icons.folder_open_rounded,
                      label: 'Files',
                      color: Colors.blue,
                      onTap: _pickFiles,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSelectionCard(
                      icon: Icons.photo_library_rounded,
                      label: 'Media',
                      color: Colors.purple,
                      onTap: _pickMedia,
                    ),
                  ),
                ],
              ),
            ] else ...[
              _buildSelectionCard(
                icon: Icons.folder_open_rounded,
                label: 'Select Files',
                color: Colors.blue,
                onTap: _pickFiles,
              ),
            ],

            const SizedBox(height: 32),

            // Selected Files
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedFiles.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Selected (${_selectedFiles.length})',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            TextButton.icon(
                              onPressed: _clearFiles,
                              icon: const Icon(Icons.clear_all, size: 20),
                              label: const Text('Clear'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _selectedFiles.length,
                            itemBuilder: (context, index) {
                              final file = _selectedFiles[index];
                              return Container(
                                width: 110,
                                margin: const EdgeInsets.only(
                                  right: 12,
                                  bottom: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(
                                        (0.05 * 255).round(),
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.insert_drive_file_rounded,
                                      size: 36,
                                      color: Colors.blue.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      p.basename(file.path),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
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

            if (_discoveredDevices.isNotEmpty) ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _discoveredDevices.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final device = _discoveredDevices[index];
                  final isSending = _sendingByDeviceId[device.id] ?? false;

                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.05 * 255).round()),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.indigo.withAlpha((0.1 * 255).round()),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.computer_rounded,
                          color: Colors.indigo,
                        ),
                      ),
                      title: Text(
                        device.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${device.ip}:${device.port}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: _selectedFiles.isNotEmpty
                          ? ElevatedButton(
                              onPressed: isSending
                                  ? null
                                  : () => _sendFilesToDevice(device),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                elevation: 0,
                              ),
                              child: isSending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Send'),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(
                                  (0.1 * 255).round(),
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.wifi,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Ready',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  );
                },
              ),
            ] else ...[
              // No devices discovered
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).cardColor.withAlpha((0.5 * 255).round()),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withAlpha((0.1 * 255).round()),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.radar_rounded,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Scanning for devices...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ensure devices are on the same Wi-Fi network',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
