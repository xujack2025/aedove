import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:network_info_plus/network_info_plus.dart';

extension IterableExtension<T> on Iterable<T> {
  Iterable<List<T>> chunked(int size) sync* {
    if (isEmpty) return;
    var iterator = this.iterator;
    var chunk = <T>[];
    while (iterator.moveNext()) {
      chunk.add(iterator.current);
      if (chunk.length == size) {
        yield chunk;
        chunk = <T>[];
      }
    }
    if (chunk.isNotEmpty) yield chunk;
  }
}

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
  static const List<int> _discoveryPorts = [8080, 8081, 8082, 8083, 8084, 8085];
  static const int _broadcastInterval = 30; // seconds
  static const int _discoveryTimeout = 5; // seconds

  static HttpServer? _server;
  static Timer? _broadcastTimer;
  static Timer? _cleanupTimer;
  static final Map<String, DeviceInfo> _discoveredDevices = {};
  static final StreamController<List<DeviceInfo>> _devicesController =
      StreamController<List<DeviceInfo>>.broadcast();

  static Stream<List<DeviceInfo>> get devicesStream =>
      _devicesController.stream;
  static List<DeviceInfo> get discoveredDevices =>
      _discoveredDevices.values.toList();

  static Future<void> start() async {
    await _startDiscoveryServer();
    await _startBroadcasting();
    await _startCleanupTimer();
  }

  static Future<void> stop() async {
    _server?.close();
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _devicesController.close();
  }

  static int _currentPort = _discoveryPorts[0];
  static int get discoveryPort => _currentPort;

  static Future<void> _startDiscoveryServer() async {
    for (final port in _discoveryPorts) {
      try {
        _server = await HttpServer.bind(
          InternetAddress.anyIPv4, 
          port,
          shared: true // Enable socket sharing
        );
        _currentPort = port;
        _server!.listen((HttpRequest request) {
          _handleDiscoveryRequest(request);
        });
        print('Successfully bound to port $_currentPort');
        return;
      } catch (e) {
        print('Failed to bind to port $port: $e');
        continue;
      }
    }
    throw Exception('Failed to bind to any available port');
  }

  static Future<void> _handleDiscoveryRequest(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/discover') {
        // Return device info
        final deviceInfo = await _getDeviceInfo();
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(deviceInfo.toJson()))
          ..close();
      } else if (request.method == 'POST' && request.uri.path == '/register') {
        // Register a new device
        final body = await utf8.decodeStream(request);
        final deviceData = jsonDecode(body);
        final deviceInfo = DeviceInfo.fromJson(deviceData);

        _discoveredDevices[deviceInfo.id] = deviceInfo;
        _devicesController.add(_discoveredDevices.values.toList());

        request.response
          ..statusCode = 200
          ..write('OK')
          ..close();
      }
    } catch (e) {
      print('Error handling discovery request: $e');
      request.response
        ..statusCode = 500
        ..write('Error')
        ..close();
    }
  }

  static Future<void> _startBroadcasting() async {
    // Initial broadcast
    await broadcastPresence();

    // Start periodic broadcasting
    _broadcastTimer = Timer.periodic(
      const Duration(seconds: _broadcastInterval),
      (timer) async {
        await broadcastPresence();
      },
    );

    // Initial device discovery
    await discoverDevices();
  }

  static Future<void> _startCleanupTimer() async {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      _cleanupOfflineDevices();
    });
  }

  static Future<void> broadcastPresence([String? ip]) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      String? currentIP;
      
      if (Platform.isWindows) {
        try {
          final interfaces = await NetworkInterface.list(
            includeLinkLocal: false,
            type: InternetAddressType.IPv4,
          );
          
          for (var interface in interfaces) {
            for (var addr in interface.addresses) {
              if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
                currentIP = addr.address;
                break;
              }
            }
            if (currentIP != null) break;
          }
        } catch (e) {
          print('Error getting Windows IP for broadcast: $e');
        }
      } else {
        final networkInfo = NetworkInfo();
        currentIP = ip ?? await networkInfo.getWifiIP();
      }

      if (currentIP == null) {
        print('Could not determine current IP for broadcasting');
        return;
      }
      
      print('Broadcasting presence from IP: $currentIP');

      // Broadcast to all devices in the network
      final networkBase = _getNetworkBase(currentIP);

      for (int i = 1; i <= 254; i++) {
        final targetIP = '$networkBase.$i';
        if (targetIP == currentIP) continue;

        _sendBroadcast(targetIP, deviceInfo);
      }
    } catch (e) {
      print('Broadcast error: $e');
    }
  }

  static Future<void> discoverDevices([String? ip]) async {
    try {
      String? currentIP;
      
      if (Platform.isWindows) {
        try {
          final interfaces = await NetworkInterface.list(
            includeLinkLocal: false,
            type: InternetAddressType.IPv4,
          );
          
          // Find the first non-loopback IPv4 address
          for (var interface in interfaces) {
            for (var addr in interface.addresses) {
              if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
                currentIP = addr.address;
                break;
              }
            }
            if (currentIP != null) break;
          }
        } catch (e) {
          print('Error getting Windows IP: $e');
        }
      } else {
        final networkInfo = NetworkInfo();
        currentIP = ip ?? await networkInfo.getWifiIP();
      }

      if (currentIP == null) {
        print('Could not determine current IP address');
        return;
      }

      final networkBase = _getNetworkBase(currentIP);
      print('Starting device discovery on network: $networkBase.*');

      // Create a list of all discovery tasks
      List<Future<void>> discoveryTasks = [];
      
      for (int i = 1; i <= 254; i++) {
        final targetIP = '$networkBase.$i';
        if (targetIP == currentIP) continue;
        
        // Add discovery task to the list
        discoveryTasks.add(_discoverDevice(targetIP).timeout(
          const Duration(seconds: 2),
          onTimeout: () => print('Discovery timeout for $targetIP'),
        ));
      }

      // Run discovery tasks in parallel with a maximum of 10 concurrent tasks
      final chunks = discoveryTasks.chunked(10);
      for (final chunk in chunks) {
        await Future.wait(chunk).catchError((e) {
          print('Error in discovery chunk: $e');
        });
      }
      
      print('Device discovery completed');
    } catch (e) {
      print('Device discovery error: $e');
    }
  }

  static Future<void> _sendBroadcast(String ip, DeviceInfo deviceInfo) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 1);

      // Try both IPv4 and IPv6
      List<String> addresses = [ip];
      try {
        final lookupResult = await InternetAddress.lookup(ip);
        addresses.addAll(lookupResult.map((addr) => addr.address));
      } catch (e) {
        print('Address lookup error: $e');
      }

      for (final address in addresses) {
        try {
          final request = await client.postUrl(
            Uri.parse('http://$address:$_currentPort/register'),
          );
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(deviceInfo.toJson()));

          final response = await request.close();
          if (response.statusCode == 200) {
            // Device is online, update our list
            _discoveredDevices[deviceInfo.id] = deviceInfo;
            _devicesController.add(_discoveredDevices.values.toList());
            break; // Successfully contacted the device
          }
        } catch (e) {
          // Continue trying other addresses
          continue;
        }
      }
    } catch (e) {
      print('Broadcast error: $e');
    }
  }

  static Future<void> _discoverDevice(String ip) async {
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: _discoveryTimeout);

      print('Attempting to discover device at $ip:$_currentPort');
      final request = await client.getUrl(
        Uri.parse('http://$ip:$_currentPort/discover'),
      );

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await utf8.decodeStream(response);
        final deviceData = jsonDecode(body);
        final deviceInfo = DeviceInfo.fromJson(deviceData);

        print('Found device: ${deviceInfo.name} at ${deviceInfo.ip}:${deviceInfo.port}');
        _discoveredDevices[deviceInfo.id] = deviceInfo;
        _devicesController.add(_discoveredDevices.values.toList());
      } else {
        print('Got non-200 response from $ip: ${response.statusCode}');
      }
    } catch (e) {
      // Only log connection errors if they're not typical "host unreachable" errors
      if (!e.toString().contains('Connection refused') && 
          !e.toString().contains('Connection timed out')) {
        print('Error discovering device at $ip: $e');
      }
    } finally {
      client.close();
    }
  }

  static Future<DeviceInfo> _getDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceInfo = DeviceInfoPlugin();

    String deviceId = prefs.getString('device_id') ?? const Uuid().v4();
    String deviceName = prefs.getString('device_name') ?? 'CPS Share Device';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceName = androidInfo.model;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceName = iosInfo.name;
    }

    String ipAddress = 'unknown';
    
    if (Platform.isWindows) {
      try {
        final interfaces = await NetworkInterface.list(
          includeLinkLocal: false,
          type: InternetAddressType.IPv4,
        );
        
        // Find the first non-loopback IPv4 address
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              ipAddress = addr.address;
              break;
            }
          }
          if (ipAddress != 'unknown') break;
        }
        print('Windows IP address detected: $ipAddress');
      } catch (e) {
        print('Error getting Windows IP: $e');
      }
    } else {
      final networkInfo = NetworkInfo();
      ipAddress = await networkInfo.getWifiIP() ?? 'unknown';
    }

    return DeviceInfo(
      id: deviceId,
      name: deviceName,
      ip: ipAddress,
      port: _currentPort,
      lastSeen: DateTime.now(),
    );
  }

  static String _getNetworkBase(String ip) {
    final parts = ip.split('.');
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  static void _cleanupOfflineDevices() {
    final now = DateTime.now();
    final offlineThreshold = const Duration(minutes: 2);

    _discoveredDevices.removeWhere((id, device) {
      return now.difference(device.lastSeen) > offlineThreshold;
    });

    _devicesController.add(_discoveredDevices.values.toList());
  }
}
