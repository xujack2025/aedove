import 'package:aedove/domain/entities/device_entity.dart';
import 'package:aedove/presentation/bloc/discovery/discovery_bloc.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:aedove/services/file_transfer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


class SendTab extends StatefulWidget {
  const SendTab({super.key});

  @override
  State<SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<SendTab> {
  List<File> _selectedFiles = [];
  final Map<String, bool> _sendingByDeviceId = {};
  final Map<String, bool> _sentSuccessfullyByDeviceId = {};
  String _deviceId = '';
  bool _isPickerActive = false; // Track if a picker is currently active
  bool _isLoadingFiles = false; // Track if files are being loaded/validated
  String _loadingMessage =
      'Processing files...'; // Message to show during loading

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
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _isLoadingFiles = true;
          _loadingMessage = 'Validating files...';
        });

        // Process files in background to show loading state
        final files = <File>[];
        int skippedDirectories = 0;

        for (final platformFile in result.files) {
          if (platformFile.path != null) {
            try {
              final file = File(platformFile.path!);
              // Check if it's actually a directory (e.g., .band files on iOS)
              final stat = await FileStat.stat(platformFile.path!);
              if (stat.type == FileSystemEntityType.directory) {
                debugPrint('Skipping directory: ${platformFile.path}');
                skippedDirectories++;
                continue;
              }
              // Verify it's a regular file and accessible
              if (stat.type == FileSystemEntityType.file &&
                  await file.exists()) {
                files.add(file);
              }
            } catch (e) {
              debugPrint('Error checking file ${platformFile.path}: $e');
            }
          }
        }

        setState(() {
          _selectedFiles = files;
          _isLoadingFiles = false;
        });

        if (skippedDirectories > 0) {
          _showErrorSnackBar(
            'Selected ${files.length} file(s). Skipped $skippedDirectories package/directory item(s).',
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingFiles = false;
      });
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

      // Use wechat_assets_picker for better UX
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // Request photo permission
        final PermissionState ps = await PhotoManager.requestPermissionExtend();
        if (!ps.hasAccess) {
          _showErrorSnackBar('Permission denied. Please grant photo access.');
          setState(() {
            _isPickerActive = false;
          });
          return;
        }

        // Use wechat_assets_picker - shows selected items immediately
        if (!mounted) return;
        final List<AssetEntity>? result = await AssetPicker.pickAssets(
          context,
          pickerConfig: AssetPickerConfig(
            maxAssets: 50,
            requestType: RequestType.common, // Photos and videos
            textDelegate: const EnglishAssetPickerTextDelegate(),
          ),
        );

        debugPrint('📱 Assets picker returned ${result?.length ?? 0} items');

        if (result == null || result.isEmpty) {
          setState(() {
            _isPickerActive = false;
          });
          return;
        }

        // Show loading state immediately
        if (mounted) {
          setState(() {
            _isLoadingFiles = true;
            _loadingMessage = 'Processing ${result.length} file(s)...';
          });
        }

        // Convert AssetEntity to File
        try {
          final validFiles = <File>[];
          final totalSelected = result.length;

          for (int i = 0; i < result.length; i++) {
            final asset = result[i];

            try {
              // Update progress message
              setState(() {
                _loadingMessage = 'Processing file ${i + 1}/$totalSelected...';
              });

              debugPrint(
                'Processing asset ${i + 1}/$totalSelected (${asset.type})...',
              );

              // Get file from asset
              final file = await asset.file;

              if (file == null) {
                debugPrint('Skipping asset: file is null');
                continue;
              }

              // Verify file
              if (await file.exists()) {
                final length = await file.length();
                if (length > 0) {
                  validFiles.add(file);
                  debugPrint('Asset processed: ${file.path} ($length bytes)');
                } else {
                  debugPrint('Skipping empty file');
                }
              } else {
                debugPrint('File does not exist: ${file.path}');
              }
            } catch (e) {
              debugPrint('Error processing asset ${i + 1}: $e');
            }
          }

          if (validFiles.isNotEmpty) {
            setState(() {
              _selectedFiles = validFiles;
              _isLoadingFiles = false;
            });

            // Show feedback if some files were rejected
            final rejected = totalSelected - validFiles.length;
            if (rejected > 0) {
              _showErrorSnackBar(
                'Selected ${validFiles.length} file(s). $rejected file(s) skipped',
              );
            }
          } else if (totalSelected > 0) {
            setState(() {
              _isLoadingFiles = false;
            });
            _showErrorSnackBar(
              'All selected files were unavailable. Please try different files.',
            );
          } else {
            setState(() {
              _isLoadingFiles = false;
            });
          }
        } catch (assetPickerError) {
          debugPrint('AssetPicker error: $assetPickerError');
          _showErrorSnackBar('Error selecting media: $assetPickerError');
          setState(() {
            _isLoadingFiles = false;
          });
        } finally {
          setState(() {
            _isPickerActive = false;
            _isLoadingFiles = false;
          });
        }
        return;
      }

      // Fallback: generic file picker filtered to media
      try {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.media,
        );
        if (result != null && result.files.isNotEmpty) {
          // Validate each file
          final validFiles = <File>[];
          final totalSelected = result.files.length;

          for (final platformFile in result.files) {
            if (platformFile.path == null || platformFile.path!.isEmpty) {
              debugPrint('Skipping file with null/empty path');
              continue;
            }

            try {
              final file = File(platformFile.path!);
              if (await file.exists()) {
                final length = await file.length();
                if (length > 0) {
                  // Optionally validate mime type
                  final mimeType = lookupMimeType(platformFile.path!);
                  if (mimeType != null &&
                      (mimeType.startsWith('image/') ||
                          mimeType.startsWith('video/'))) {
                    validFiles.add(file);
                  } else {
                    debugPrint(
                      'Skipping non-media file: ${platformFile.path} (mime: $mimeType)',
                    );
                  }
                } else {
                  debugPrint('Skipping empty file: ${platformFile.path}');
                }
              } else {
                debugPrint('File does not exist: ${platformFile.path}');
              }
            } catch (e) {
              debugPrint('Error validating file ${platformFile.path}: $e');
            }
          }

          // Show loading state while validating files
          setState(() {
            _isLoadingFiles = true;
          });

          if (validFiles.isNotEmpty) {
            setState(() {
              _selectedFiles = validFiles;
              _isLoadingFiles = false;
            });

            final rejected = totalSelected - validFiles.length;
            if (rejected > 0) {
              _showErrorSnackBar(
                'Selected ${validFiles.length} file(s). $rejected file(s) skipped (unsupported type)',
              );
            }
          } else if (totalSelected > 0) {
            setState(() {
              _isLoadingFiles = false;
            });
            _showErrorSnackBar(
              'All selected files were unsupported. Please select image or video files.',
            );
          } else {
            setState(() {
              _isLoadingFiles = false;
            });
          }
        }
      } catch (filePickerError) {
        debugPrint('FilePicker error: $filePickerError');
        _showErrorSnackBar('Error picking media: $filePickerError');
        setState(() {
          _isLoadingFiles = false;
        });
      } finally {
        // Make sure we reset the picker state even if FilePicker was cancelled
        setState(() {
          _isPickerActive = false;
          _isLoadingFiles = false;
        });
      }
    } catch (e) {
      debugPrint('Unexpected error in _pickMedia: $e');
      _showErrorSnackBar('Error picking media: $e');
      setState(() {
        _isLoadingFiles = false;
      });
    } finally {
      setState(() {
        _isPickerActive = false;
        _isLoadingFiles = false;
      });
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

      // Show tick icon for 2 seconds instead of popup
      setState(() {
        _sendingByDeviceId[device.id] = false;
        _sentSuccessfullyByDeviceId[device.id] = true;
      });

      // Reset to send button after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _sentSuccessfullyByDeviceId[device.id] = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error sending files: $e');
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

  Widget _buildSelectionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
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
      ),
    );
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

          // Loading indicator when processing files
          if (_isLoadingFiles) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.1 * 255).round()),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _loadingMessage,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

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
                        height:
                            180, // 1. Increased height slightly to accommodate the padding
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          // 2. Allow shadows to paint outside the scroll view bounds
                          clipBehavior: Clip.none,
                          // 3. Add padding around the entire list so the first/last items
                          // and top/bottom shadows aren't cut off
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          itemCount: _selectedFiles.length,
                          itemBuilder: (context, index) {
                            final file = _selectedFiles[index];
                            return Container(
                              width: 110,
                              // 4. Removed 'bottom' margin (handled by ListView padding now)
                              // Kept 'right' margin to separate items from each other
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(
                                      (0.1 * 255).round(),
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
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
                                  FutureBuilder<String>(
                                    future: _getFileSizeText(file),
                                    builder: (context, snapshot) {
                                      return Text(
                                        snapshot.data ?? 'Calculating...',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color,
                                        ),
                                      );
                                    },
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

          if (discoveredDevices.isNotEmpty) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: discoveredDevices.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final device = discoveredDevices[index];
                final isSending = _sendingByDeviceId[device.id] ?? false;
                final sentSuccessfully =
                    _sentSuccessfullyByDeviceId[device.id] ?? false;

                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.1 * 255).round()),
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
                        Icons.devices_rounded,
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
                            onPressed: (isSending || sentSuccessfully)
                                ? null
                                : () => _sendFilesToDevice(device),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: sentSuccessfully
                                  ? Colors.green
                                  : Colors.indigo,
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
                                : sentSuccessfully
                                ? const Icon(Icons.check, size: 20)
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
                  Icon(Icons.radar_rounded, size: 64, color: Colors.grey[300]),
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
    );
  }
}
