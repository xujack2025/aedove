import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:bonsoir/bonsoir.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:cpshare/services/file_transfer_service.dart';

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
  static const String _serviceType = '_cpshare._tcp';
  static String? _currentDeviceId;
  static const int _mdnsPort = 53317; // Port for mDNS service
  static const int _udpPort = 53318; // Separate port for UDP broadcast
  static const int _broadcastInterval = 30; // seconds
  static const Duration _cleanupThreshold = Duration(minutes: 5);
  static const Duration _reconnectDelay = Duration(seconds: 5);

  static BonsoirBroadcast? _broadcast;
  static BonsoirDiscovery? _discovery;
  static RawDatagramSocket? _udpSocket;
  static Timer? _broadcastTimer;
  static Timer? _cleanupTimer;
  static Timer? _reconnectTimer;
  static Timer? _networkCheckTimer;

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

    try {
      _isInitializing = true;
      print('Starting device discovery service...');

      // Get and store current device ID first
      final deviceInfo = await _getDeviceInfo();
      _currentDeviceId = deviceInfo.id;

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
    await _startUdpBroadcast();
    await _startCleanupTimer();
    _startNetworkMonitoring();
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
            FileTransferService.getPrimaryPort(), // Use the file transfer port
        attributes: {
          'id': deviceInfo.id,
          'ip': deviceInfo.ip,
          'udp_port': _udpPort.toString(),
          'transfer_port': FileTransferService.getPrimaryPort().toString(),
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

      // Set up discovery listener with more aggressive discovery
      _discovery?.eventStream?.listen((event) {
        print(
          'Received mDNS event: ${event.runtimeType} - ${event.toString()}',
        );
        if (event.service != null) {
          print('Service details: ${event.service?.toJson()}');
          if (event.toString().contains('Found') ||
              event.toString().contains('Resolved')) {
            _handleDiscoveredService(event.service);
          } else if (event.toString().contains('Lost')) {
            _handleLostService(event.service);
          }
        }
      }, onError: (e) => print('mDNS event error: $e'));

      // Set up periodic service discovery refresh
      Timer.periodic(const Duration(seconds: 10), (_) {
        if (_discovery != null && _isStarted) {
          print('Refreshing mDNS discovery...');
          _discovery!.start().catchError(
            (e) => print('Error refreshing mDNS discovery: $e'),
          );
        }
      });

      // Start broadcast if available
      if (_broadcast != null) {
        try {
          await _broadcast!.start().timeout(
            const Duration(seconds: 5),
            onTimeout: () =>
                throw TimeoutException('Broadcast start timed out'),
          );
          print('Broadcast service started');
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
          print('Discovery service started');
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
      print('mDNS service started successfully');
    } catch (e) {
      print('Error starting mDNS service: $e');
      rethrow;
    }
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

      // Create new socket
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _udpPort,
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
          print('UDP socket error: $e');
          _scheduleReconnect();
        },
        onDone: () {
          print('UDP socket closed unexpectedly');
          _scheduleReconnect();
        },
      );

      // Start periodic broadcast
      _broadcastTimer?.cancel();
      _broadcastTimer = Timer.periodic(
        Duration(seconds: _broadcastInterval),
        (_) => _sendUdpBroadcast(),
      );

      // Send initial broadcast
      await _sendUdpBroadcast();
      print('UDP broadcast service started successfully');
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
        print('Attempting to reconnect UDP service...');
        try {
          await _initializeUdpSocket();
        } catch (e) {
          print('Reconnection attempt failed: $e');
        }
      }
    });
  }

  static Future<void> _sendUdpBroadcast() async {
    if (!_isStarted) return;

    try {
      final deviceInfo = await _getDeviceInfo();
      if (deviceInfo.ip == 'unknown') return;

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
                // Ignore individual send errors
              }
            }
          }
        }
      } else {
        // Original broadcast logic for other platforms
        // ...existing broadcast code...
      }
    } catch (e) {
      print('Error sending UDP broadcast: $e');
    }
  }

  static void _handleUdpMessage(RawDatagramSocket socket) {
    final datagram = socket.receive();
    if (datagram == null) return;

    try {
      final message = utf8.decode(datagram.data);
      final data = jsonDecode(message);

      if (data['type'] == 'discovery') {
        final deviceInfo = DeviceInfo.fromJson(data['data']);

        // Skip if this is our own device
        if (deviceInfo.id == _currentDeviceId) {
          return;
        }

        print('Found device via UDP: ${deviceInfo.toJson()}');

        // Send response only to other devices
        _sendUdpResponse(datagram.address, datagram.port);
        _updateDiscoveredDevice(deviceInfo);
      }
    } catch (e) {
      print('Error handling UDP message: $e');
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
      print('Sent UDP response to ${address.address}:$port');
    } catch (e) {
      print('Error sending UDP response: $e');
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

      // If IP is not in attributes, try to get from addresses
      if (serviceIp == null) {
        final addresses = service.toJson()['addresses'] as List<dynamic>?;
        if (addresses != null && addresses.isNotEmpty) {
          serviceIp = addresses.first.toString();
        }
      }

      // Get UDP port from attributes if available
      int port = _mdnsPort; // Default to mDNS port
      final attrPort = attributes['udp_port'];
      if (attrPort != null) {
        port = int.tryParse(attrPort.toString()) ?? _mdnsPort;
      }

      // If we have an IP address, create the device info
      if (serviceIp != null) {
        final deviceInfo = DeviceInfo(
          id: serviceId ?? const Uuid().v4(),
          name: service.name,
          ip: serviceIp,
          port: port,
          lastSeen: DateTime.now(),
        );
        _updateDiscoveredDevice(deviceInfo);
      }
    } catch (e) {
      print('Error handling discovered service: $e');
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
      print('Error handling lost service: $e');
    }
  }

  static void _updateDiscoveredDevice(DeviceInfo deviceInfo) {
    if (deviceInfo.id.isEmpty || deviceInfo.ip == 'unknown') return;

    _discoveredDevices[deviceInfo.id] = deviceInfo;
    _devicesController.add(_discoveredDevices.values.toList());
    print('Updated device: ${deviceInfo.toJson()}');
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
        if (shouldRemove) {
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
            _udpSocket?.send(
              utf8.encode('ping'),
              InternetAddress('127.0.0.1'),
              _udpPort,
            );
          } catch (e) {
            print('UDP socket test failed, scheduling reconnect...');
            _scheduleReconnect();
          }
        }
      } catch (e) {
        print('Error during network check: $e');
      }
    });
  }

  static Future<DeviceInfo> _getDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceInfo = DeviceInfoPlugin();

    String deviceId = prefs.getString('device_id') ?? const Uuid().v4();
    await prefs.setString('device_id', deviceId);

    String deviceName = prefs.getString('device_name') ?? 'CP Share Device';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceName = androidInfo.model;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceName = iosInfo.name;
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
      port: _mdnsPort, // Use mDNS port as the primary port
      lastSeen: DateTime.now(),
    );
  }
}
