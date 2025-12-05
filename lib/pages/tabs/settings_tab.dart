import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 20,
            spreadRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 24.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your device and preferences',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
            ),
          ),
          const SizedBox(height: 32),

          // Device Information
          _buildSectionCard(
            title: 'Device Information',
            icon: Icons.devices_other_rounded,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha((0.1 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Device Name',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(_deviceName),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showDeviceNameDialog(),
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withAlpha((0.1 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.purple,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Device ID',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _deviceId,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha((0.1 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'IP Address',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _ipAddress,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // File Transfer Preferences
          _buildSectionCard(
            title: 'Preferences',
            icon: Icons.tune_rounded,
            children: [
              SwitchListTile(
                // 1. Remove EdgeInsets.zero so it aligns with the title above it
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: const Text(
                  'Notifications',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('Show alerts for file transfers'),
                value: _notificationsEnabled,
                // 2. FIX: Set distinct colors for the Thumb (circle) and Track (background)
                // When ON: White circle on Blue background
                activeThumbColor: Colors.white,
                activeTrackColor: Theme.of(context).colorScheme.primary,
                // Optional: Style the "Off" state if needed
                inactiveThumbColor: Colors.grey.shade600,
                inactiveTrackColor: Colors.grey.shade300,

                onChanged: (value) async {
                  await _saveSetting('notifications_enabled', value);
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Contact Us Section
          _buildSectionCard(
            title: 'Contact Us',
            icon: Icons.contact_mail_rounded,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha((0.1 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Advertise With Us',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('Post your ads in our app'),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () {
                  // TODO: Replace with actual contact/ads URL
                  _showContactDialog();
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // About Us Section
          _buildSectionCard(
            title: 'About',
            icon: Icons.info_outline_rounded,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withAlpha((0.1 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Colors.teal,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Version',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('1.1.1'),
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withAlpha((0.1 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: Colors.indigo,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('Automated WiFi file sharing app'),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
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

  Future<void> _showContactDialog() async {
    const url = 'https://aedove.com/contact.html';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open contact page'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error opening contact page'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
