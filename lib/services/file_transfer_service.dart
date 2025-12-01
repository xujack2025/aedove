import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aedove/services/notification_service.dart';
import 'package:aedove/services/media_store_service.dart';
import 'package:path/path.dart' as p;

enum TransferStatus { pending, transferring, completed, failed }

class FileTransferProgress {
  final String requestId;
  final String fileName;
  final int totalBytes;
  final int transferredBytes;
  final TransferStatus status;
  final DateTime startTime;
  final String? errorMessage;

  FileTransferProgress({
    required this.requestId,
    required this.fileName,
    required this.totalBytes,
    required this.transferredBytes,
    required this.status,
    required this.startTime,
    this.errorMessage,
  });

  double get progress => totalBytes > 0 ? transferredBytes / totalBytes : 0.0;

  Duration get elapsed => DateTime.now().difference(startTime);

  Duration? get estimatedTimeRemaining {
    if (transferredBytes <= 0 || status != TransferStatus.transferring) {
      return null;
    }
    final bytesPerSecond = transferredBytes / elapsed.inSeconds;
    if (bytesPerSecond <= 0) return null;
    final remainingBytes = totalBytes - transferredBytes;
    final secondsRemaining = remainingBytes / bytesPerSecond;
    return Duration(seconds: secondsRemaining.ceil());
  }

  String get progressPercent => '${(progress * 100).toStringAsFixed(0)}%';
}

class FileTransferRequest {
  final String id;
  final String senderId;
  final String senderName;
  final String fileName;
  final int fileSize;
  final String fileType;
  final DateTime timestamp;
  String ipAddress = '';
  String targetDeviceIP = '';
  // Local path for outgoing files (only set on sender)
  String? localFilePath;

  FileTransferRequest({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender_id': senderId,
    'sender_name': senderName,
    'file_name': fileName,
    'file_size': fileSize,
    'file_type': fileType,
    'timestamp': timestamp.toIso8601String(),
  };

  factory FileTransferRequest.fromJson(Map<String, dynamic> json) =>
      FileTransferRequest(
        id: json['id'],
        senderId: json['sender_id'],
        senderName: json['sender_name'],
        fileName: json['file_name'],
        fileSize: json['file_size'],
        fileType: json['file_type'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class FileTransferService {
  static const List<int> _fileTransferPorts = [8081, 8082, 8083, 8084, 8085];
  static int _currentPort = _fileTransferPorts[0];
  static const bool _verbose = false; // Set to true to enable detailed logging

  /// Get the primary port used for file transfers
  static int getPrimaryPort() => _fileTransferPorts[0];

  /// Get the actual bound server port
  static int getServerPort() => _currentPort;
  static HttpServer? _server;
  static Timer? _healthCheckTimer;
  static final Map<String, FileTransferRequest> _pendingRequests = {};
  // Map of outgoing request id -> local file path (used by sender)
  static final Map<String, String> _outgoingFiles = {};
  static final StreamController<List<FileTransferRequest>> _requestsController =
      StreamController<List<FileTransferRequest>>.broadcast();
  // Stream that emits the path of the last saved file on the receiver
  static final StreamController<String> _fileSavedController =
      StreamController<String>.broadcast();
  // Stream that emits file transfer progress updates
  static final StreamController<FileTransferProgress> _progressController =
      StreamController<FileTransferProgress>.broadcast();
  // Map of request id -> progress info
  static final Map<String, FileTransferProgress> _activeTransfers = {};

  static Stream<List<FileTransferRequest>> get requestsStream =>
      _requestsController.stream;
  static Stream<String> get fileSavedStream => _fileSavedController.stream;
  static Stream<FileTransferProgress> get progressStream =>
      _progressController.stream;
  static List<FileTransferRequest> get pendingRequests =>
      _pendingRequests.values.toList();
  static Map<String, FileTransferProgress> get activeTransfers =>
      Map.unmodifiable(_activeTransfers);

  /// Check if the file transfer server is running
  static bool isServerRunning() {
    final running = _server != null;
    debugPrint(
      'File transfer server status: ${running ? "RUNNING on port $_currentPort" : "NOT RUNNING"}',
    );
    return running;
  }

  /// Get diagnostic information about the server
  static Map<String, dynamic> getServerDiagnostics() {
    return {
      'is_running': _server != null,
      'current_port': _currentPort,
      'pending_requests': _pendingRequests.length,
      'available_ports': _fileTransferPorts,
    };
  }

  static Future<void> start() async {
    await _startFileTransferServer();
    _startHealthCheck();
  }

  static Future<void> stop() async {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _server?.close();
    _requestsController.close();
  }

  static void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_server == null) {
        debugPrint('⚠️ File transfer server is down! Attempting to restart...');
        _startFileTransferServer().catchError((e) {
          debugPrint('Failed to restart server: $e');
        });
      } else {
        // debugPrint(
        //   '✓ File transfer server health check OK (port: $_currentPort)',
        // );
      }
    });
  }

  static Future<void> _startFileTransferServer() async {
    debugPrint('Starting file transfer server...');
    debugPrint('Attempting to bind to ports: $_fileTransferPorts');

    for (final port in _fileTransferPorts) {
      try {
        debugPrint('Trying to bind to port $port...');
        _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
        _currentPort = port;
        _server!.listen(
          (HttpRequest request) {
            _handleFileTransferRequest(request);
          },
          onError: (error) {
            debugPrint('Server error on port $_currentPort: $error');
          },
        );
        debugPrint(
          '✓ Successfully bound file transfer server to port $_currentPort',
        );
        debugPrint('Server listening on 0.0.0.0:$_currentPort');
        return;
      } catch (e, stackTrace) {
        debugPrint('✗ Failed to bind file transfer server to port $port');
        debugPrint('Error: $e');
        if (e.toString().contains('Address already in use') ||
            e.toString().contains('bind failed')) {
          debugPrint('Port $port is already in use, trying next port...');
        } else {
          debugPrint('Unexpected error: $e');
          debugPrint('Stack trace: $stackTrace');
        }
        continue;
      }
    }

    // If all ports failed, provide detailed error information
    final errorMsg =
        'Failed to bind file transfer server to any available port. '
        'Tried ports: $_fileTransferPorts. This may be due to: '
        '1) All ports are in use, '
        '2) Firewall/security settings blocking ports, '
        '3) Device-specific network restrictions. '
        'Please restart the app or check device settings.';
    debugPrint('ERROR: $errorMsg');
    throw Exception(errorMsg);
  }

  static Future<void> _handleFileTransferRequest(HttpRequest request) async {
    debugPrint('Received ${request.method} request to ${request.uri.path}');
    try {
      final remoteAddress = request.connectionInfo?.remoteAddress.address;
      if (remoteAddress == null || remoteAddress.isEmpty) {
        debugPrint('Error: No remote address available');
        request.response
          ..statusCode = 400
          ..write('No remote address')
          ..close();
        return;
      }
      debugPrint('Remote address: $remoteAddress');

      if (request.method == 'POST' && request.uri.path == '/request') {
        // Handle file transfer request
        debugPrint('Handling file transfer request...');
        final body = await utf8.decodeStream(request);
        debugPrint('Request body received: ${body.length} bytes');
        final requestData = jsonDecode(body);
        debugPrint('Request data parsed: $requestData');
        final transferRequest = FileTransferRequest.fromJson(requestData);
        transferRequest.ipAddress = remoteAddress;
        transferRequest.targetDeviceIP = remoteAddress;

        // Don't add to pending if it's from our own device (sender)
        final myDeviceId = await _getDeviceId();
        debugPrint(
          'Comparing sender ID: ${transferRequest.senderId} with my ID: $myDeviceId',
        );
        if (transferRequest.senderId == myDeviceId) {
          debugPrint('Ignoring file transfer request from own device');
          request.response
            ..statusCode = 200
            ..write('OK')
            ..close();
          return;
        }
        debugPrint('Request is from different device, adding to pending list');

        _pendingRequests[transferRequest.id] = transferRequest;
        _requestsController.add(_pendingRequests.values.toList());
        debugPrint('Transfer request added to pending list');

        // Show notification
        try {
          await NotificationService.showFileTransferNotification(
            senderId: transferRequest.senderId,
            fileName: transferRequest.fileName,
            fileSize: _formatFileSize(transferRequest.fileSize),
          );
          debugPrint('Notification shown successfully');
        } catch (e) {
          debugPrint('Error showing notification: $e');
          // Don't fail the request if notification fails
        }

        request.response
          ..statusCode = 200
          ..write('OK')
          ..close();
        debugPrint('Response sent: 200 OK');
      } else if (request.method == 'POST' && request.uri.path == '/accept') {
        // Handle file transfer acceptance (sender side receives this when
        // receiver accepted our request). The sender should push file bytes
        // to the receiver's /transfer endpoint.
        final body = await utf8.decodeStream(request);
        final data = jsonDecode(body);
        final requestId = data['request_id'];

        // Respond immediately to prevent timeout on receiver side
        request.response
          ..statusCode = 200
          ..write('OK')
          ..close();

        // Now send file in background (non-blocking)
        if (_outgoingFiles.containsKey(requestId)) {
          final remoteAddress = request.connectionInfo?.remoteAddress.address;
          if (remoteAddress != null) {
            final localPath = _outgoingFiles[requestId];
            if (localPath != null) {
              // Execute file transfer asynchronously without blocking
              unawaited(
                Future(() async {
                  try {
                    final file = File(localPath);
                    if (await file.exists()) {
                      final bytes = await file.readAsBytes();
                      bool sent = false;

                      // Try all available ports to send file to receiver
                      for (final port in _fileTransferPorts) {
                        final client = http.Client();
                        try {
                          debugPrint(
                            'Trying to send file to receiver on port $port',
                          );
                          final uri = Uri.parse(
                            'http://$remoteAddress:$port/transfer',
                          );
                          final timeout = _calculateFileTransferTimeout(
                            bytes.length,
                          );
                          debugPrint(
                            'Transferring ${_formatFileSize(bytes.length)} with ${timeout.inSeconds}s timeout',
                          );
                          final resp = await client
                              .post(
                                uri,
                                headers: {
                                  'Content-Type': 'application/octet-stream',
                                  'request_id': requestId,
                                  'file_name': Uri.encodeComponent(
                                    p.basename(localPath),
                                  ),
                                },
                                body: bytes,
                              )
                              .timeout(timeout);
                          client.close();

                          if (resp.statusCode == 200) {
                            debugPrint(
                              'Successfully sent file to receiver on port $port',
                            );
                            // Clean up pending/outgoing entries
                            _outgoingFiles.remove(requestId);
                            _pendingRequests.remove(requestId);
                            _requestsController.add(
                              _pendingRequests.values.toList(),
                            );
                            sent = true;
                            break;
                          } else {
                            debugPrint(
                              'Failed to push file on port $port: ${resp.statusCode}',
                            );
                          }
                        } catch (e) {
                          debugPrint('Error sending to port $port: $e');
                          client.close();
                          continue;
                        }
                      }

                      if (!sent) {
                        debugPrint(
                          'Failed to send file to receiver on any port',
                        );
                      }
                    } else {
                      debugPrint('Local file not found to send: $localPath');
                    }
                  } catch (e) {
                    debugPrint('Error sending file bytes to receiver: $e');
                  }
                }),
              );
            } else {
              debugPrint('No local file path found for request $requestId');
            }
          } else {
            debugPrint('No remote address available for /accept request');
          }
        }
      } else if (request.method == 'POST' && request.uri.path == '/transfer') {
        // Receiver: accept raw file bytes from sender
        final requestId = request.headers.value('request_id') ?? '';
        final encodedFileName =
            request.headers.value('file_name') ?? 'received_file';
        final fileName = Uri.decodeComponent(encodedFileName);
        try {
          // Get file size from pending request if available
          final int? expectedSize = _pendingRequests[requestId]?.fileSize;

          // Initialize progress tracking
          if (expectedSize != null) {
            final progress = FileTransferProgress(
              requestId: requestId,
              fileName: fileName,
              totalBytes: expectedSize,
              transferredBytes: 0,
              status: TransferStatus.transferring,
              startTime: DateTime.now(),
            );
            _activeTransfers[requestId] = progress;
            _progressController.add(progress);
          }

          // Collect all bytes from the request
          final bytes = await request.fold<List<int>>([], (previous, element) {
            final updated = previous..addAll(element);
            // Emit progress updates
            if (expectedSize != null) {
              final progress = FileTransferProgress(
                requestId: requestId,
                fileName: fileName,
                totalBytes: expectedSize,
                transferredBytes: updated.length,
                status: TransferStatus.transferring,
                startTime:
                    _activeTransfers[requestId]?.startTime ?? DateTime.now(),
              );
              _activeTransfers[requestId] = progress;
              _progressController.add(progress);
            }
            return updated;
          });

          // Save using MediaStoreService which handles platform differences
          try {
            final filePath = await MediaStoreService.saveFile(fileName, bytes);

            // Mark transfer as completed
            final completedProgress = FileTransferProgress(
              requestId: requestId,
              fileName: fileName,
              totalBytes: bytes.length,
              transferredBytes: bytes.length,
              status: TransferStatus.completed,
              startTime:
                  _activeTransfers[requestId]?.startTime ?? DateTime.now(),
            );
            _activeTransfers[requestId] = completedProgress;
            _progressController.add(completedProgress);

            // Notify user
            if (_pendingRequests.containsKey(requestId)) {
              final tr = _pendingRequests[requestId]!;
              await NotificationService.showFileReceivedNotification(
                fileName: tr.fileName,
                fileSize: _formatFileSize(tr.fileSize),
                filePath: filePath,
                isIOS: Platform.isIOS,
              );
              _pendingRequests.remove(requestId);
              _requestsController.add(_pendingRequests.values.toList());
              // Emit saved file path for UI listeners
              try {
                _fileSavedController.add(filePath);
              } catch (_) {}
            } else {
              await NotificationService.showFileReceivedNotification(
                fileName: fileName,
                fileSize: _formatFileSize(bytes.length),
                filePath: filePath,
                isIOS: Platform.isIOS,
              );
              try {
                _fileSavedController.add(filePath);
              } catch (_) {}
            }

            // Clean up progress after a delay
            Future.delayed(const Duration(seconds: 3), () {
              _activeTransfers.remove(requestId);
            });

            request.response
              ..statusCode = 200
              ..write('OK')
              ..close();
          } catch (e) {
            debugPrint('Error saving file: $e');
            // Mark transfer as failed
            final failedProgress = FileTransferProgress(
              requestId: requestId,
              fileName: fileName,
              totalBytes: expectedSize ?? 0,
              transferredBytes: 0,
              status: TransferStatus.failed,
              startTime:
                  _activeTransfers[requestId]?.startTime ?? DateTime.now(),
              errorMessage: e.toString(),
            );
            _activeTransfers[requestId] = failedProgress;
            _progressController.add(failedProgress);
            Future.delayed(const Duration(seconds: 5), () {
              _activeTransfers.remove(requestId);
            });
            request.response
              ..statusCode = 500
              ..write('Error saving file: $e')
              ..close();
          }
        } catch (e) {
          debugPrint('Error receiving file transfer: $e');
          // Mark transfer as failed
          if (requestId.isNotEmpty) {
            final failedProgress = FileTransferProgress(
              requestId: requestId,
              fileName: encodedFileName,
              totalBytes: 0,
              transferredBytes: 0,
              status: TransferStatus.failed,
              startTime: DateTime.now(),
              errorMessage: e.toString(),
            );
            _activeTransfers[requestId] = failedProgress;
            _progressController.add(failedProgress);
          }
          request.response
            ..statusCode = 500
            ..write('Error receiving file: $e')
            ..close();
        }
      } else if (request.method == 'POST' && request.uri.path == '/deny') {
        // Handle file transfer denial
        final body = await utf8.decodeStream(request);
        final data = jsonDecode(body);
        final requestId = data['request_id'];

        // Clean up both pending requests and outgoing files
        _pendingRequests.remove(requestId);
        _outgoingFiles.remove(requestId);
        _requestsController.add(_pendingRequests.values.toList());

        request.response
          ..statusCode = 200
          ..write('OK')
          ..close();
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR handling file transfer request: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint(
        'Request method: ${request.method}, path: ${request.uri.path}',
      );
      try {
        request.response
          ..statusCode = 500
          ..write('Error: $e')
          ..close();
      } catch (responseError) {
        debugPrint('Failed to send error response: $responseError');
      }
    }
  }

  static Future<void> sendFile({
    required String targetDeviceId,
    required String targetDeviceIP,
    required String filePath,
    required String fileName,
    int? targetDevicePort, // Prefer receiver's advertised port if known
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      final fileSize = await file.length();
      final fileType = _getFileType(fileName);

      // Create transfer request
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();
      final transferRequest = FileTransferRequest(
        id: requestId,
        senderId: await _getDeviceId(),
        senderName: await _getDeviceName(),
        fileName: fileName,
        fileSize: fileSize,
        fileType: fileType,
        timestamp: DateTime.now(),
      );

      // Set target device IP and local file path for later use
      transferRequest.targetDeviceIP = targetDeviceIP;
      transferRequest.localFilePath = filePath;

      // Keep track of outgoing file so we can send bytes if the receiver accepts
      // Note: We do NOT add outgoing requests to _pendingRequests
      // Only incoming requests from other devices should appear there
      _outgoingFiles[requestId] = filePath;

      // Try to send request to target device on all available ports
      bool sent = false;
      Exception? lastError;

      // Build a prioritized port list: preferred (if provided), current server port, then others
      final Set<int> portsSet = {
        if (targetDevicePort != null) targetDevicePort,
        getPrimaryPort(),
        _currentPort,
        ..._fileTransferPorts,
      };
      final portsToTry = portsSet.toList();
      for (final port in portsToTry) {
        final client = http.Client();
        try {
          final uri = Uri(
            scheme: 'http',
            host: targetDeviceIP,
            port: port,
            path: '/request',
          );
          if (_verbose) {
            debugPrint('Trying to send request to: $uri');
          }

          final response = await client
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(transferRequest.toJson()),
              )
              .timeout(
                const Duration(seconds: 3),
              ); // Increased timeout slightly

          if (response.statusCode == 200) {
            debugPrint('Successfully sent file transfer request to port $port');
            // Show notification that file was ready to be sent
            await NotificationService.showFileSentNotification(
              fileName: fileName,
              fileSize: _formatFileSize(fileSize),
            );
            sent = true;
            break;
          } else if (_verbose) {
            debugPrint(
              'Got non-200 response from port $port: ${response.statusCode}',
            );
          }
        } catch (e) {
          lastError = e as Exception;
          if (_verbose) {
            debugPrint('Failed to send to port $port: $e');
          }
          continue;
        } finally {
          client.close();
        }
      }

      if (!sent) {
        debugPrint('Failed to send file transfer request to target device');
        if (lastError != null && _verbose) {
          debugPrint('Last error: $lastError');
        }
        _pendingRequests.remove(requestId);
        _outgoingFiles.remove(requestId);
        _requestsController.add(_pendingRequests.values.toList());
      }
    } catch (e) {
      debugPrint('Error sending file: $e');
    }
  }

  static Future<void> acceptFileTransfer(String requestId) async {
    try {
      final request = _pendingRequests[requestId];
      if (request == null) return;

      bool accepted = false;
      Exception? lastError;

      for (final port in _fileTransferPorts) {
        final client = http.Client();
        try {
          debugPrint('Trying to send accept request to port $port');
          final response = await client
              .post(
                Uri.parse('http://${request.ipAddress}:$port/accept'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'request_id': requestId}),
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            debugPrint('Successfully sent accept request to port $port');
            accepted = true;
            break;
          }
        } catch (e) {
          lastError = Exception(e.toString());
          debugPrint('Failed to send accept to port $port: $e');
          continue;
        } finally {
          client.close();
        }
      }

      if (!accepted) {
        debugPrint('Failed to send accept request to any port');
        if (lastError != null) {
          debugPrint('Last error: $lastError');
        }
      }

      // Note: Don't remove from pending here - will be removed when file is received in /transfer endpoint
    } catch (e) {
      debugPrint('Error accepting file transfer: $e');
    }
  }

  static Future<void> denyFileTransfer(String requestId) async {
    try {
      final request = _pendingRequests[requestId];
      if (request == null) return;

      // If ipAddress is empty, this is likely our own outgoing request
      // Just remove it locally without trying to send deny to sender
      if (request.ipAddress.isEmpty) {
        debugPrint('Denying local/outgoing request (no remote IP)');
        _pendingRequests.remove(requestId);
        _outgoingFiles.remove(requestId);
        _requestsController.add(_pendingRequests.values.toList());
        return;
      }

      bool denied = false;
      Exception? lastError;

      for (final port in _fileTransferPorts) {
        final client = http.Client();
        try {
          debugPrint('Trying to send deny request to port $port');
          final response = await client
              .post(
                Uri.parse('http://${request.ipAddress}:$port/deny'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'request_id': requestId}),
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            debugPrint('Successfully sent deny request to port $port');
            denied = true;
            break;
          }
        } catch (e) {
          lastError = Exception(e.toString());
          debugPrint('Failed to send deny to port $port: $e');
          continue;
        } finally {
          client.close();
        }
      }

      if (!denied) {
        debugPrint('Failed to send deny request to any port');
        if (lastError != null) {
          debugPrint('Last error: $lastError');
        }
      }

      // Always remove from local pending requests (receiver side cleanup)
      _pendingRequests.remove(requestId);
      _requestsController.add(_pendingRequests.values.toList());
    } catch (e) {
      debugPrint('Error denying file transfer: $e');
    }
  }

  /// Calculate timeout duration based on file size
  /// Base timeout of 30 seconds + 5 seconds per 10MB
  /// Examples: 10MB=35s, 100MB=80s, 1GB=542s (~9min), 10GB=5130s (~85min)
  static Duration _calculateFileTransferTimeout(int fileSizeBytes) {
    const baseSeconds = 30;
    const secondsPer10MB = 5;
    const bytesIn10MB = 10 * 1024 * 1024;

    final additionalSeconds = (fileSizeBytes / bytesIn10MB * secondsPer10MB)
        .ceil();
    return Duration(seconds: baseSeconds + additionalSeconds);
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image';
      case 'mp4':
      case 'avi':
      case 'mov':
        return 'video';
      case 'mp3':
      case 'wav':
      case 'flac':
        return 'audio';
      case 'pdf':
        return 'document';
      case 'txt':
      case 'doc':
      case 'docx':
        return 'text';
      default:
        return 'file';
    }
  }

  static Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_id') ?? 'unknown';
  }

  static Future<String> _getDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_name') ?? 'Aedove Device';
  }
}
