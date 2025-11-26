import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:bonsoir/bonsoir.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:aedove/services/file_transfer_service.dart';

class DeviceInfo {
  final String id;
  final String name;
  final String ip;
  final int port;
  final DateTime lastSeen;
  final bool isOnline;

  DeviceInfo({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.lastSeen,
    this.isOnline = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ip': ip,
    'port': port,
    'last_seen': lastSeen.toIso8601String(),
    'is_online': isOnline,
  };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
    id: json['id'],
    name: json['name'],
    ip: json['ip'],
    port: json['port'],
    lastSeen: DateTime.parse(json['last_seen']),
    isOnline: json['is_online'] ?? true,
  );
}

class DeviceDiscoveryService {
  static const String _serviceType = '_aedove._tcp';
  static String? _currentDeviceId;
  static String? _currentDeviceIp; // cache own IP to avoid processing self
  static const int _mdnsPort = 53317; // Port for mDNS service
  static const int _udpPort = 53318; // Separate port for UDP broadcast
  static const int _broadcastInterval = 30; // seconds
  static const Duration _cleanupThreshold = Duration(minutes: 5);
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static bool _verbose = false; // set to true to enable detailed logs

  static BonsoirBroadcast? _broadcast;
  static BonsoirDiscovery? _discovery;
  static RawDatagramSocket? _udpSocket;
  static Timer? _broadcastTimer;
  static Timer? _cleanupTimer;
  static Timer? _reconnectTimer;
  static Timer? _networkCheckTimer;
  static Timer? _mdnsRefreshTimer;

  static bool _isStarted = false;
  static bool _isInitializing = false;
  static final Map<String, DeviceInfo> _discoveredDevices = {};
  static final StreamController<List<DeviceInfo>> _devicesController =
      StreamController<List<DeviceInfo>>.broadcast();
  static const Duration _timeoutDuration = Duration(seconds: 30);

  static Stream<List<DeviceInfo>> get devicesStream =>
      _devicesController.stream;
  static List<DeviceInfo> get discoveredDevices =>
      _discoveredDevices.values.toList();

  static Future<void> start() async {
    if (_isStarted) {
      print('Device discovery service is already running');
      return;
    }

    if (_isInitializing) {
      print('Device discovery service is already initializing');
      return;
    }

    try {
      _isInitializing = true;
      print('Starting device discovery service...');

      // Get and store current device ID/IP first
      final deviceInfo = await _getDeviceInfo();
      _currentDeviceId = deviceInfo.id;
      _currentDeviceIp = deviceInfo.ip; // cache own ip

      await _initializeServices().timeout(
        _timeoutDuration,
        onTimeout: () {
          throw TimeoutException('Service initialization timed out');
        },
      );

      _isStarted = true;
      print('Device discovery service started successfully');
    } catch (e, stackTrace) {
      print('Failed to start device discovery service: $e');
      print('Stack trace: $stackTrace');
      await stop();
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  static Future<void> _initializeServices() async {
    await _startMdnsService();
    // Start UDP socket on all platforms to listen; only non-iOS will broadcast
    await _startUdpBroadcast();
    await _startCleanupTimer();
    _startNetworkMonitoring();
    _startAndroidMdnsFallback();
    _startWindowsMdnsFallback();
  }

  static Future<void> stop() async {
    print('Stopping device discovery service...');
    _isStarted = false;

    try {
      // Stop broadcast service with timeout
      if (_broadcast != null) {
        try {
          await _broadcast!.stop().timeout(
            const Duration(seconds: 5),
            onTimeout: () => print('Broadcast stop timed out'),
          );
        } catch (e) {
          print('Error stopping broadcast service: $e');
        } finally {
          _broadcast = null;
        }
      }

      // Stop discovery service with timeout
      if (_discovery != null) {
        try {
          await _discovery!.stop().timeout(
            const Duration(seconds: 5),
            onTimeout: () => print('Discovery stop timed out'),
          );
        } catch (e) {
          print('Error stopping discovery service: $e');
        } finally {
          _discovery = null;
        }
      }

      // Clean up UDP resources
      if (_udpSocket != null) {
        try {
          _udpSocket!.close();
        } catch (e) {
          print('Error closing UDP socket: $e');
        } finally {
          _udpSocket = null;
        }
      }

      // Cancel timers
      _broadcastTimer?.cancel();
      _cleanupTimer?.cancel();
      _broadcastTimer = null;
      _cleanupTimer = null;

      // Clear discovered devices
      _discoveredDevices.clear();

      // Cancel all timers
      _networkCheckTimer?.cancel();
      _reconnectTimer?.cancel();
      _mdnsRefreshTimer?.cancel();

      print('Device discovery service stopped successfully');
    } catch (e) {
      print('Error stopping device discovery service: $e');
    } finally {
      // Ensure all resources are cleared even if there were errors
      _broadcast = null;
      _discovery = null;
      _udpSocket = null;
      _broadcastTimer = null;
      _cleanupTimer = null;
      _networkCheckTimer = null;
      _reconnectTimer = null;
      _mdnsRefreshTimer = null;
      _isInitializing = false;
    }
  }

  static Future<void> _startMdnsService() async {
    print('Initializing mDNS service...');
    try {
      final deviceInfo = await _getDeviceInfo();
      if (deviceInfo.ip == 'unknown') {
        throw Exception('Could not determine device IP address');
      }

      print('Device info: ${deviceInfo.toJson()}');

      // Create the service with a unique name and file transfer port
      final service = BonsoirService(
        name: '${deviceInfo.name}_${deviceInfo.id.substring(0, 8)}',
        type: _serviceType,
        port:
            FileTransferService.getServerPort(), // Advertise actual file transfer port
        attributes: {
          // Use short TXT keys (Android NSD discourages > 9 chars)
          'id': deviceInfo.id,
          'ip': deviceInfo.ip,
          'tport': FileTransferService.getServerPort().toString(),
          'uport': _udpPort.toString(),
        },
      );

      // Initialize broadcast with error handling
      try {
        _broadcast = BonsoirBroadcast(service: service);
        await _broadcast?.initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () =>
              throw TimeoutException('Broadcast initialization timed out'),
        );
        print('Broadcast service initialized');
      } catch (e) {
        print('Error initializing broadcast service: $e');
        _broadcast = null;
      }

      // Initialize discovery with error handling
      try {
        _discovery = BonsoirDiscovery(type: _serviceType);
        await _discovery?.initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () =>
              throw TimeoutException('Discovery initialization timed out'),
        );
        print('Discovery service initialized');
      } catch (e) {
        print('Error initializing discovery service: $e');
        _discovery = null;
      }

      // Verify at least one service initialized
      if (_broadcast == null && _discovery == null) {
        throw Exception(
          'Failed to initialize both broadcast and discovery services',
        );
      }

      // Set up discovery listener with resolution when needed
      _discovery?.eventStream?.listen((event) async {
        if (_verbose) {
          print(
            'Received mDNS event: ${event.runtimeType} - ${event.toString()}',
          );
        }
        if (event.service != null) {
          if (_verbose) {
            print('Service details: ${event.service?.toJson()}');
          }
          if (event.toString().contains('Found') ||
              event.toString().contains('Resolved') ||
              event.toString().contains('Updated')) {
            final service = event.service!;
            // We include IP/ports in attributes, so resolution is optional. Handle as-is.
            await _handleDiscoveredService(service);
          } else if (event.toString().contains('Lost')) {
            _handleLostService(event.service);
          }
        }
      }, onError: (e) => _verbose ? print('mDNS event error: $e') : null);

      // Removed frequent mDNS restart to reduce noise and instability.

      // Start broadcast if available
      if (_broadcast != null) {
        try {
          await _broadcast!.start().timeout(
            const Duration(seconds: 5),
            onTimeout: () =>
                throw TimeoutException('Broadcast start timed out'),
          );
          if (_verbose) print('Broadcast service started');
        } catch (e) {
          print('Error starting broadcast service: $e');
          _broadcast = null;
        }
      }

      // Start discovery if available
      if (_discovery != null) {
        try {
          await _discovery!.start().timeout(
            const Duration(seconds: 5),
            onTimeout: () =>
                throw TimeoutException('Discovery start timed out'),
          );
          if (_verbose) print('Discovery service started');
        } catch (e) {
          print('Error starting discovery service: $e');
          _discovery = null;
        }
      }

      // Final check to ensure at least one service is running
      if (_broadcast == null && _discovery == null) {
        throw Exception(
          'Failed to start both broadcast and discovery services',
        );
      }
      if (_verbose) print('mDNS service started successfully');
    } catch (e) {
      print('Error starting mDNS service: $e');
      rethrow;
    }
  }

  // Android NSD can provide empty/incorrect TXT/port. Use multicast_dns as a fallback
  static void _startAndroidMdnsFallback() {
    _mdnsRefreshTimer?.cancel();
    if (!Platform.isAndroid) return;
    _mdnsRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!_isStarted) return;
      try {
        final client = MDnsClient();
        await client.start();

        // Query for our service type
        await for (final ptr in client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(_serviceType),
        )) {
          final instance = ptr.domainName; // e.g., "Name._aedove._tcp.local"

          // Resolve SRV for port/target
          SrvResourceRecord? srv;
          await for (final s in client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(instance),
          )) {
            srv = s;
            break;
          }

          // Resolve TXT for attributes
          Map<String, String> txtMap = {};
          await for (final txt in client.lookup<TxtResourceRecord>(
            ResourceRecordQuery.text(instance),
          )) {
            final dynamic raw = txt.text;
            final List<String> entries = raw is List<String>
                ? raw
                : raw is String
                ? <String>[raw]
                : <String>[];
            for (final entry in entries) {
              final idx = entry.indexOf('=');
              if (idx > 0) {
                final k = entry.substring(0, idx);
                final v = entry.substring(idx + 1);
                txtMap[k] = v;
              }
            }
            break;
          }

          // Resolve A record for IPv4
          String? ip;
          if (srv != null) {
            await for (final a in client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target),
            )) {
              ip = a.address.address;
              break;
            }
          }

          final id = txtMap['id'] ?? '';
          if (id.isEmpty || id == _currentDeviceId) continue;

          final tport = int.tryParse(txtMap['tport'] ?? '') ?? (srv?.port ?? 0);
          final resolvedIp = txtMap['ip'] ?? ip;
          if (resolvedIp == null || resolvedIp.isEmpty || tport <= 0) continue;

          final device = DeviceInfo(
            id: id,
            name: instance.split('._').first,
            ip: resolvedIp,
            port: tport,
            lastSeen: DateTime.now(),
          );
          _updateDiscoveredDevice(device);
        }
        client.stop();
      } catch (e) {
        if (_verbose) print('multicast_dns fallback error: $e');
      }
    });
  }

  static void _startWindowsMdnsFallback() {
    if (!Platform.isWindows) return;
    _mdnsRefreshTimer?.cancel();
    _mdnsRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!_isStarted) return;
      try {
        final client = MDnsClient();
        await client.start();
        await for (final ptr in client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(_serviceType),
        )) {
          final instance = ptr.domainName;
          SrvResourceRecord? srv;
          await for (final s in client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(instance),
          )) {
            srv = s;
            break;
          }
          Map<String, String> txtMap = {};
          await for (final txt in client.lookup<TxtResourceRecord>(
            ResourceRecordQuery.text(instance),
          )) {
            final dynamic raw = txt.text;
            final List<String> entries = raw is List<String>
                ? raw
                : raw is String
                ? <String>[raw]
                : <String>[];
            for (final entry in entries) {
              final idx = entry.indexOf('=');
              if (idx > 0) {
                txtMap[entry.substring(0, idx)] = entry.substring(idx + 1);
              }
            }
            break;
          }
          String? ip;
          if (srv != null) {
            await for (final a in client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target),
            )) {
              ip = a.address.address;
              break;
            }
          }
          final id = txtMap['id'] ?? '';
          if (id.isEmpty || id == _currentDeviceId) continue;
          final tport = int.tryParse(txtMap['tport'] ?? '') ?? (srv?.port ?? 0);
          final resolvedIp = txtMap['ip'] ?? ip;
          if (resolvedIp == null || resolvedIp.isEmpty || tport <= 0) continue;
          final device = DeviceInfo(
            id: id,
            name: instance.split('._').first,
            ip: resolvedIp,
            port: tport,
            lastSeen: DateTime.now(),
          );
          _updateDiscoveredDevice(device);
        }
        client.stop();
      } catch (e) {
        if (_verbose) print('windows multicast_dns fallback error: $e');
      }
    });
  }

  static Future<void> _startUdpBroadcast() async {
    print('Starting UDP broadcast service...');
    await _initializeUdpSocket();
  }

  static Future<void> _initializeUdpSocket() async {
    try {
      // Close existing socket if any
      _udpSocket?.close();
      _udpSocket = null;

      // Create new socket without reusePort to avoid Android compatibility issues
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _udpPort,
        reuseAddress:
            true, // Use reuseAddress instead of reusePort for better compatibility
        reusePort: false, // Explicitly disable reusePort on Android
      );
      _udpSocket!.broadcastEnabled = true;

      // Listen for incoming discovery messages with error handling
      _udpSocket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            _handleUdpMessage(_udpSocket!);
          }
        },
        onError: (e) {
          // Suppress reusePort warnings as they're not critical
          if (e.toString().contains('reusePort')) {
            return; // Ignore this specific error
          }
          print('UDP socket error: $e');
          // Don't reconnect immediately on every error to avoid loop
          // Only reconnect if socket is actually broken
          if (e.toString().contains('Closed') ||
              e.toString().contains('Bad file descriptor')) {
            try {
              _udpSocket?.close();
            } catch (_) {}
            _udpSocket = null;
            _scheduleReconnect();
          }
        },
        onDone: () {
          print('UDP socket closed unexpectedly');
          try {
            _udpSocket?.close();
          } catch (_) {}
          _udpSocket = null;
          _scheduleReconnect();
        },
        cancelOnError: false, // Keep listening even after errors
      );

      // Start periodic broadcast (disable on iOS: only listen/respond)
      _broadcastTimer?.cancel();
      if (!Platform.isIOS) {
        _broadcastTimer = Timer.periodic(
          Duration(seconds: _broadcastInterval),
          (_) => _sendUdpBroadcast(),
        );
        // Send initial broadcast
        await _sendUdpBroadcast();
      }
      if (_verbose) print('UDP broadcast service started successfully');
    } catch (e) {
      print('Error initializing UDP socket: $e');
      _scheduleReconnect();
      rethrow;
    }
  }

  static void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      if (_isStarted && !_isInitializing) {
        if (_verbose) print('Attempting to reconnect UDP service...');
        try {
          await _initializeUdpSocket();
        } catch (e) {
          if (_verbose) print('Reconnection attempt failed: $e');
        }
      }
    });
  }

  static Future<void> _sendUdpBroadcast() async {
    if (!_isStarted) return;
    if (_udpSocket == null) {
      print('UDP socket is null, skipping broadcast');
      return;
    }

    try {
      final deviceInfo = await _getDeviceInfo();
      if (deviceInfo.ip == 'unknown') {
        if (_verbose) print('Cannot broadcast: IP address unknown');
        return;
      }

      final message = jsonEncode({
        'type': 'discovery',
        'data': deviceInfo.toJson(),
      });

      // For Windows, use only subnet-specific broadcast
      if (Platform.isWindows) {
        final parts = deviceInfo.ip.split('.');
        if (parts.length == 4) {
          final networkBase = '${parts[0]}.${parts[1]}.${parts[2]}';

          // Limit the broadcast range on Windows to prevent flooding
          for (int i = 1; i <= 254; i += 2) {
            final targetIp = '$networkBase.$i';
            if (targetIp != deviceInfo.ip) {
              try {
                _udpSocket?.send(
                  utf8.encode(message),
                  InternetAddress(targetIp),
                  _udpPort,
                );
                // Add small delay to prevent flooding
                await Future.delayed(const Duration(milliseconds: 5));
              } catch (e) {
                // Silently ignore individual send errors to prevent spam
                if (_verbose) print('Failed to send to $targetIp: $e');
              }
            }
          }
        }
      } else {
        // Non-Windows platforms
        final parts = deviceInfo.ip.split('.');
        if (parts.length == 4) {
          final networkBase = '${parts[0]}.${parts[1]}.${parts[2]}';
          // macOS/Android/Linux: try global and directed broadcast
          if (!Platform.isIOS) {
            // Global broadcast (some routers drop it, but cheap win when it works)
            try {
              _udpSocket?.send(
                utf8.encode(message),
                InternetAddress('255.255.255.255'),
                _udpPort,
              );
            } catch (e) {
              if (_verbose) print('Global broadcast failed: $e');
            }
            // Directed broadcast for the subnet
            try {
              _udpSocket?.send(
                utf8.encode(message),
                InternetAddress('$networkBase.255'),
                _udpPort,
              );
            } catch (e) {
              if (_verbose) print('Subnet broadcast failed: $e');
            }
          } else {
            // iOS: avoid 255.255.255.255. Probe subnet sparsely to reduce cost
            for (int i = 1; i <= 254; i += 4) {
              final targetIp = '$networkBase.$i';
              if (targetIp != deviceInfo.ip) {
                try {
                  _udpSocket?.send(
                    utf8.encode(message),
                    InternetAddress(targetIp),
                    _udpPort,
                  );
                  await Future.delayed(const Duration(milliseconds: 2));
                } catch (e) {
                  if (_verbose) print('Failed to send to $targetIp: $e');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      if (_verbose) print('Error sending UDP broadcast: $e');
      // Don't rethrow - let the timer continue
    }
  }

  static void _handleUdpMessage(RawDatagramSocket socket) {
    final datagram = socket.receive();
    if (datagram == null) return;

    try {
      final message = utf8.decode(datagram.data);
      final trimmed = message.trimLeft();
      // Ignore non-JSON payloads silently
      if (!trimmed.startsWith('{')) {
        if (_verbose) {
          print(
            'Ignored non-JSON UDP payload from ${datagram.address.address}:${datagram.port}',
          );
        }
        return;
      }
      final data = jsonDecode(trimmed);
      if (data is! Map) return;

      final String? type = data['type'];
      if (type == null) return;

      if (type == 'health_check') {
        // Local health check, no action needed
        return;
      }

      if (type == 'discovery' || type == 'discovery_response') {
        final deviceInfo = DeviceInfo.fromJson(data['data']);

        // Skip if this is our own device
        if (deviceInfo.id == _currentDeviceId) {
          return;
        }

        if (_verbose)
          print('Found device via UDP ($type): ${deviceInfo.toJson()}');

        // If we received a discovery (not a response), reply.
        if (type == 'discovery') {
          _sendUdpResponse(datagram.address, datagram.port);
        }
        _updateDiscoveredDevice(deviceInfo);
      }
    } catch (e) {
      if (_verbose) print('Error handling UDP message: $e');
    }
  }

  static Future<void> _sendUdpResponse(
    InternetAddress address,
    int port,
  ) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      if (deviceInfo.ip == 'unknown') return;

      final message = jsonEncode({
        'type': 'discovery_response',
        'data': deviceInfo.toJson(),
      });

      _udpSocket?.send(utf8.encode(message), address, port);
      if (_verbose) print('Sent UDP response to ${address.address}:$port');
    } catch (e) {
      if (_verbose) print('Error sending UDP response: $e');
    }
  }

  static Future<void> _handleDiscoveredService(BonsoirService? service) async {
    if (service == null) return;

    try {
      final attributes = service.attributes;
      String? serviceIp;
      String? serviceId;

      // Try to get ID and IP from attributes
      final attrId = attributes['id'];
      final attrIp = attributes['ip'];
      if (attrId != null) serviceId = attrId.toString();
      if (attrIp != null) serviceIp = attrIp.toString();

      // Skip our own service
      if (serviceId != null && serviceId == _currentDeviceId) {
        return;
      }

      // If IP is not in attributes, try to get from addresses
      if (serviceIp == null) {
        final addresses = service.toJson()['addresses'] as List<dynamic>?;
        if (addresses != null && addresses.isNotEmpty) {
          serviceIp = addresses.first.toString();
        }
      }

      // Skip if service resolves to our own IP (self)
      try {
        final me = await _getDeviceInfo();
        if (serviceIp != null && me.ip == serviceIp) {
          return;
        }
      } catch (_) {}

      // Prefer transfer port (tport), then service.port, then uport, then fallback
      int port = service.port != 0 ? service.port : _mdnsPort;
      final tportAttr = attributes['tport'];
      final uportAttr = attributes['uport'];
      if (tportAttr != null) {
        port = int.tryParse(tportAttr.toString()) ?? port;
      } else if (uportAttr != null) {
        port = int.tryParse(uportAttr.toString()) ?? port;
      }

      // Ensure we have the mandatory data we need to establish a connection
      if (serviceId == null || serviceIp == null || port <= 0) {
        if (_verbose) {
          print(
            'Ignoring mDNS record due to missing data. id: $serviceId, ip: $serviceIp, port: $port',
          );
        }
        return;
      }

      final deviceInfo = DeviceInfo(
        id: serviceId,
        name: service.name,
        ip: serviceIp,
        port: port,
        lastSeen: DateTime.now(),
      );
      _updateDiscoveredDevice(deviceInfo);
    } catch (e) {
      if (_verbose) print('Error handling discovered service: $e');
    }
  }

  static void _handleLostService(BonsoirService? service) {
    if (service == null) return;

    try {
      final attributes = service.attributes;
      final attrId = attributes['id'];
      final deviceId = attrId?.toString();

      if (deviceId != null) {
        _discoveredDevices.remove(deviceId);
        _devicesController.add(_discoveredDevices.values.toList());
      }
    } catch (e) {
      if (_verbose) print('Error handling lost service: $e');
    }
  }

  static void _updateDiscoveredDevice(DeviceInfo deviceInfo) {
    if (deviceInfo.id.isEmpty || deviceInfo.ip == 'unknown') return;
    // Ignore self by id or ip
    if (deviceInfo.id == _currentDeviceId ||
        deviceInfo.ip == _currentDeviceIp) {
      return;
    }

    // Ignore records missing a usable transfer port
    if (deviceInfo.port <= 0) {
      if (_verbose) {
        print('Ignoring device without valid port: ${deviceInfo.toJson()}');
      }
      return;
    }

    // Deduplicate by IP. Retain the entry that contains the most useful information (valid port wins)
    String existingKey = '';
    for (final e in _discoveredDevices.entries) {
      if (e.value.ip == deviceInfo.ip && e.key != deviceInfo.id) {
        existingKey = e.key;
        break;
      }
    }
    if (existingKey.isNotEmpty) {
      final existing = _discoveredDevices[existingKey]!;
      // If current record lacks port but existing has one, keep existing
      if (existing.port > 0 && deviceInfo.port <= 0) {
        return;
      }
      _discoveredDevices.remove(existingKey);
    }

    _discoveredDevices[deviceInfo.id] = deviceInfo;
    _devicesController.add(_discoveredDevices.values.toList());
    if (_verbose) print('Updated device: ${deviceInfo.toJson()}');
  }

  static Future<void> _startCleanupTimer() async {
    _cleanupTimer?.cancel();
    final cleanupInterval = Platform.isWindows
        ? const Duration(seconds: 30) // More frequent cleanup on Windows
        : const Duration(minutes: 1); // Normal interval for other platforms

    _cleanupTimer = Timer.periodic(cleanupInterval, (_) {
      final now = DateTime.now();
      _discoveredDevices.removeWhere((_, device) {
        final shouldRemove =
            now.difference(device.lastSeen) > _cleanupThreshold;
        if (_verbose && shouldRemove) {
          print('Removing stale device: ${device.toJson()}');
        }
        return shouldRemove;
      });
      _devicesController.add(_discoveredDevices.values.toList());
    });
  }

  static void _startNetworkMonitoring() {
    _networkCheckTimer?.cancel();
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_isStarted || _isInitializing) return;

      try {
        final currentInfo = await _getDeviceInfo();
        if (currentInfo.ip == 'unknown') {
          print('Network appears to be down, scheduling reconnect...');
          _scheduleReconnect();
        } else {
          // Verify UDP socket is still functional
          try {
            if (!Platform.isIOS) {
              final healthMsg = jsonEncode({
                'type': 'health_check',
                'ts': DateTime.now().millisecondsSinceEpoch,
              });
              _udpSocket?.send(
                utf8.encode(healthMsg),
                InternetAddress('127.0.0.1'),
                _udpPort,
              );
            }
          } catch (e) {
            if (_verbose) {
              print('UDP socket test failed, scheduling reconnect...');
            }
            _scheduleReconnect();
          }
        }
      } catch (e) {
        if (_verbose) print('Error during network check: $e');
      }
    });
  }

  static Future<DeviceInfo> _getDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceInfo = DeviceInfoPlugin();

    String deviceId = prefs.getString('device_id') ?? const Uuid().v4();
    await prefs.setString('device_id', deviceId);

    // Check if user has set a custom device name
    String? customDeviceName = prefs.getString('device_name');
    String deviceName;

    if (customDeviceName != null && customDeviceName.isNotEmpty) {
      // Use custom device name set by user
      deviceName = customDeviceName;
    } else {
      // Use default device name based on platform + IP
      String defaultName = 'Aedove Device';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        defaultName = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        defaultName = iosInfo.name;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        defaultName = windowsInfo.computerName;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        defaultName = macInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        defaultName = linuxInfo.prettyName ?? 'Linux Device';
      }

      deviceName = defaultName;
    }

    String ipAddress;
    try {
      if (Platform.isWindows) {
        final interfaces = await NetworkInterface.list(
          includeLinkLocal: false,
          type: InternetAddressType.IPv4,
        );
        ipAddress = 'unknown';
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              ipAddress = addr.address;
              break;
            }
          }
          if (ipAddress != 'unknown') break;
        }
      } else {
        final networkInfo = NetworkInfo();
        ipAddress = await networkInfo.getWifiIP() ?? 'unknown';
      }

      if (ipAddress == 'unknown') {
        // Fallback to manual network interface check
        final interfaces = await NetworkInterface.list(
          includeLinkLocal: false,
          type: InternetAddressType.IPv4,
        );
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              ipAddress = addr.address;
              break;
            }
          }
          if (ipAddress != 'unknown') break;
        }
      }
    } catch (e) {
      print('Error getting IP address: $e');
      ipAddress = 'unknown';
    }

    return DeviceInfo(
      id: deviceId,
      name: deviceName,
      ip: ipAddress,
      // Advertise our actual file transfer port so peers can connect correctly
      port: FileTransferService.getServerPort(),
      lastSeen: DateTime.now(),
    );
  }
}
