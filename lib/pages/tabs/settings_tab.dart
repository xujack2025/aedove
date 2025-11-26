import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _deviceName = 'My Device';
  String _deviceId = 'Unknown';
  String _ipAddress = 'Unknown';
  // ignore: unused_field
  bool _autoAcceptFiles = false;
  bool _notificationsEnabled = true;
  // ignore: unused_field
  bool _backgroundServiceEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _getDeviceInfo();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceName = prefs.getString('device_name') ?? 'My Device';
      _deviceId = prefs.getString('device_id') ?? 'Unknown';
      _autoAcceptFiles = prefs.getBool('auto_accept_files') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _backgroundServiceEnabled =
          prefs.getBool('background_service_enabled') ?? true;
    });
  }

  Future<void> _getDeviceInfo() async {
    try {
      String ipAddress = 'Unknown';
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
            if (ipAddress != 'Unknown') break;
          }
        } catch (e) {
          debugPrint('Error getting Windows IP: $e');
        }
      } else {
        final networkInfo = NetworkInfo();
        final connectivityResult = await Connectivity().checkConnectivity();

        if (connectivityResult.isNotEmpty &&
            connectivityResult.first != ConnectivityResult.none) {
          ipAddress = await networkInfo.getWifiIP() ?? 'Unknown';
        }
      }

      setState(() {
        _ipAddress = ipAddress;
      });
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
  }

  Future<void> _saveDeviceName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name', name);
    setState(() {
      _deviceName = name;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 24.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Icon(
              Icons.settings,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Device Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Information',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.devices),
                      title: const Text('Device Name'),
                      subtitle: Text(_deviceName),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _showDeviceNameDialog(),
                    ),
                    ListTile(
                      leading: const Icon(Icons.fingerprint),
                      title: const Text('Device ID'),
                      subtitle: Text(_deviceId),
                    ),
                    ListTile(
                      leading: const Icon(Icons.wifi),
                      title: const Text('IP Address'),
                      subtitle: Text(_ipAddress),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // File Transfer Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'File Transfer Settings',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    // SwitchListTile(
                    //   title: const Text('Auto-accept files'),
                    //   subtitle: const Text(
                    //     'Automatically accept files from trusted devices',
                    //   ),
                    //   value: _autoAcceptFiles,
                    //   onChanged: (value) {
                    //     _saveSetting('auto_accept_files', value);
                    //   },
                    // ),
                    SwitchListTile(
                      title: const Text('Notifications'),
                      subtitle: const Text(
                        'Show notifications for file transfers',
                      ),
                      value: _notificationsEnabled,
                      onChanged: (value) async {
                        await _saveSetting('notifications_enabled', value);
                        setState(() {
                          _notificationsEnabled = value;
                        });
                      },
                    ),
                    // SwitchListTile(
                    //   title: const Text('Background Service'),
                    //   subtitle: const Text(
                    //     'Keep service running in background',
                    //   ),
                    //   value: _backgroundServiceEnabled,
                    //   onChanged: (value) {
                    //     _saveSetting('background_service_enabled', value);
                    //   },
                    // ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // App Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Information',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    const ListTile(
                      leading: Icon(Icons.info),
                      title: Text('Version'),
                      subtitle: Text('1.0.3'),
                    ),
                    const ListTile(
                      leading: Icon(Icons.description),
                      title: Text('Description'),
                      subtitle: Text('Automated WiFi file sharing app'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceNameDialog() {
    final controller = TextEditingController(text: _deviceName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Device Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Device Name',
            hintText: 'Enter device name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _saveDeviceName(controller.text);
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
