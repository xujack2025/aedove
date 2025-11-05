import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cpshare/services/notification_service.dart';
import 'package:cpshare/services/media_store_service.dart';

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

  /// Get the primary port used for file transfers
  static int getPrimaryPort() => _fileTransferPorts[0];

  /// Get the actual bound server port
  static int getServerPort() => _currentPort;
  static HttpServer? _server;
  static final Map<String, FileTransferRequest> _pendingRequests = {};
  // Map of outgoing request id -> local file path (used by sender)
  static final Map<String, String> _outgoingFiles = {};
  static final StreamController<List<FileTransferRequest>> _requestsController =
      StreamController<List<FileTransferRequest>>.broadcast();
  // Stream that emits the path of the last saved file on the receiver
  static final StreamController<String> _fileSavedController =
      StreamController<String>.broadcast();

  static Stream<List<FileTransferRequest>> get requestsStream =>
      _requestsController.stream;
  static Stream<String> get fileSavedStream => _fileSavedController.stream;
  static List<FileTransferRequest> get pendingRequests =>
      _pendingRequests.values.toList();

  static Future<void> start() async {
    await _startFileTransferServer();
  }

  static Future<void> stop() async {
    _server?.close();
    _requestsController.close();
  }

  static Future<void> _startFileTransferServer() async {
    for (final port in _fileTransferPorts) {
      try {
        _server = await HttpServer.bind(
          InternetAddress.anyIPv4,
          port,
          shared: true, // Enable socket sharing
        );
        _currentPort = port;
        _server!.listen((HttpRequest request) {
          _handleFileTransferRequest(request);
        });
        print('Successfully bound file transfer server to port $_currentPort');
        return;
      } catch (e) {
        print('Failed to bind file transfer server to port $port: $e');
        continue;
      }
    }
    throw Exception(
      'Failed to bind file transfer server to any available port',
    );
  }

  static Future<void> _handleFileTransferRequest(HttpRequest request) async {
    try {
      final remoteAddress = request.connectionInfo?.remoteAddress.address;
      if (remoteAddress == null || remoteAddress.isEmpty) {
        print('Error: No remote address available');
        request.response
          ..statusCode = 400
          ..write('No remote address')
          ..close();
        return;
      }

      if (request.method == 'POST' && request.uri.path == '/request') {
        // Handle file transfer request
        final body = await utf8.decodeStream(request);
        final requestData = jsonDecode(body);
        final transferRequest = FileTransferRequest.fromJson(requestData);
        transferRequest.ipAddress = remoteAddress;
        transferRequest.targetDeviceIP = remoteAddress;

        _pendingRequests[transferRequest.id] = transferRequest;
        _requestsController.add(_pendingRequests.values.toList());

        // Show notification
        await NotificationService.showFileTransferNotification(
          senderId: transferRequest.senderId,
          fileName: transferRequest.fileName,
          fileSize: _formatFileSize(transferRequest.fileSize),
        );

        request.response
          ..statusCode = 200
          ..write('OK')
          ..close();
      } else if (request.method == 'POST' && request.uri.path == '/accept') {
        // Handle file transfer acceptance (sender side receives this when
        // receiver accepted our request). The sender should push file bytes
        // to the receiver's /transfer endpoint.
        final body = await utf8.decodeStream(request);
        final data = jsonDecode(body);
        final requestId = data['request_id'];

        if (_pendingRequests.containsKey(requestId)) {
          final transferRequest = _pendingRequests[requestId]!;
          final remoteAddress = request.connectionInfo?.remoteAddress.address;
          if (remoteAddress != null) {
            final localPath =
                _outgoingFiles[requestId] ?? transferRequest.localFilePath;
            if (localPath != null) {
              try {
                final file = File(localPath);
                if (await file.exists()) {
                  final bytes = await file.readAsBytes();
                  final client = http.Client();
                  final uri = Uri.parse(
                    'http://$remoteAddress:$_currentPort/transfer',
                  );
                  final resp = await client.post(
                    uri,
                    headers: {
                      'Content-Type': 'application/octet-stream',
                      'request_id': requestId,
                      'file_name': transferRequest.fileName,
                    },
                    body: bytes,
                  );
                  client.close();

                  if (resp.statusCode == 200) {
                    // Clean up pending/outgoing entries
                    _outgoingFiles.remove(requestId);
                    _pendingRequests.remove(requestId);
                    _requestsController.add(_pendingRequests.values.toList());
                  } else {
                    print(
                      'Failed to push file to receiver: ${resp.statusCode}',
                    );
                  }
                } else {
                  print('Local file not found to send: $localPath');
                }
              } catch (e) {
                print('Error sending file bytes to receiver: $e');
              }
            } else {
              print('No local file path found for request $requestId');
            }
          } else {
            print('No remote address available for /accept request');
          }
        }

        request.response
          ..statusCode = 200
          ..write('OK')
          ..close();
      } else if (request.method == 'POST' && request.uri.path == '/transfer') {
        // Receiver: accept raw file bytes from sender
        try {
          final requestId = request.headers.value('request_id') ?? '';
          final fileName =
              request.headers.value('file_name') ?? 'received_file';

          // Collect all bytes from the request
          final bytes = await request.fold<List<int>>(
            [],
            (previous, element) => previous..addAll(element),
          );

          // Save using MediaStoreService which handles platform differences
          try {
            final filePath = await MediaStoreService.saveFile(fileName, bytes);

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

            request.response
              ..statusCode = 200
              ..write('OK')
              ..close();
          } catch (e) {
            print('Error saving file: $e');
            request.response
              ..statusCode = 500
              ..write('Error saving file: $e')
              ..close();
          }
        } catch (e) {
          print('Error receiving file transfer: $e');
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

        _pendingRequests.remove(requestId);
        _requestsController.add(_pendingRequests.values.toList());

        request.response
          ..statusCode = 200
          ..write('OK')
          ..close();
      }
    } catch (e) {
      print('Error handling file transfer request: $e');
      request.response
        ..statusCode = 500
        ..write('Error')
        ..close();
    }
  }

  /*static Future<void> _processFileTransfer(FileTransferRequest request) async {
    try {
      String filePath;
      if (Platform.isIOS) {
        // Get the iOS documents directory
        final documentsDir = await getApplicationDocumentsDirectory();
        filePath = '${documentsDir.path}/${request.fileName}';
      } else {
        // Android downloads directory
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        filePath = '${downloadDir.path}/${request.fileName}';
      }

      final file = File(filePath);

      // Save the file (implement actual file transfer here)
      // For now, we'll just simulate file creation
      await file.writeAsString(''); // Placeholder for actual file transfer

      // Show notification with the file location
      await NotificationService.showFileReceivedNotification(
        fileName: request.fileName,
        fileSize: _formatFileSize(request.fileSize),
        filePath: filePath,
        isIOS: Platform.isIOS,
      );
    } catch (e) {
      print('Error processing file transfer: $e');
    }
  }*/

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
      transferRequest.localFilePath = filePath;
      _outgoingFiles[requestId] = filePath;
      _pendingRequests[requestId] = transferRequest;
      _requestsController.add(_pendingRequests.values.toList());

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
          print('Trying to send request to: $uri');

          final response = await client
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(transferRequest.toJson()),
              )
              .timeout(const Duration(seconds: 2));

          if (response.statusCode == 200) {
            print('Successfully sent file transfer request to port $port');
            // Show notification that file was ready to be sent
            await NotificationService.showFileSentNotification(
              fileName: fileName,
              fileSize: _formatFileSize(fileSize),
            );
            sent = true;
            break;
          } else {
            print(
              'Got non-200 response from port $port: ${response.statusCode}',
            );
          }
        } catch (e) {
          lastError = e as Exception;
          print('Failed to send to port $port: $e');
          continue;
        } finally {
          client.close();
        }
      }

      if (!sent) {
        print('Failed to send file transfer request to any port');
        if (lastError != null) {
          print('Last error: $lastError');
        }
        _pendingRequests.remove(requestId);
        _outgoingFiles.remove(requestId);
        _requestsController.add(_pendingRequests.values.toList());
      }
    } catch (e) {
      print('Error sending file: $e');
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
          print('Trying to send accept request to port $port');
          final response = await client
              .post(
                Uri.parse('http://${request.ipAddress}:$port/accept'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'request_id': requestId}),
              )
              .timeout(const Duration(seconds: 2));

          if (response.statusCode == 200) {
            print('Successfully sent accept request to port $port');
            accepted = true;
            break;
          }
        } catch (e) {
          lastError = e as Exception;
          print('Failed to send accept to port $port: $e');
          continue;
        } finally {
          client.close();
        }
      }

      if (!accepted) {
        print('Failed to send accept request to any port');
        if (lastError != null) {
          print('Last error: $lastError');
        }
      }
    } catch (e) {
      print('Error accepting file transfer: $e');
    }
  }

  static Future<void> denyFileTransfer(String requestId) async {
    try {
      final request = _pendingRequests[requestId];
      if (request == null) return;

      bool denied = false;
      Exception? lastError;

      for (final port in _fileTransferPorts) {
        final client = http.Client();
        try {
          print('Trying to send deny request to port $port');
          final response = await client
              .post(
                Uri.parse('http://${request.ipAddress}:$port/deny'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'request_id': requestId}),
              )
              .timeout(const Duration(seconds: 2));

          if (response.statusCode == 200) {
            print('Successfully sent deny request to port $port');
            denied = true;
            break;
          }
        } catch (e) {
          lastError = e as Exception;
          print('Failed to send deny to port $port: $e');
          continue;
        } finally {
          client.close();
        }
      }

      if (!denied) {
        print('Failed to send deny request to any port');
        if (lastError != null) {
          print('Last error: $lastError');
        }
      }
    } catch (e) {
      print('Error denying file transfer: $e');
    }
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
    return prefs.getString('device_name') ?? 'CPS Share Device';
  }
}
