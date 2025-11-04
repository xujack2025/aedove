import 'package:flutter/material.dart';
import 'package:cpshare/pages/tabs/receive_tab.dart';
import 'package:cpshare/pages/tabs/send_tab.dart';
import 'package:cpshare/pages/tabs/settings_tab.dart';
import 'package:cpshare/services/permission_service.dart';
import 'package:cpshare/services/device_discovery_service.dart';

enum HomeTab {
  receive(Icons.wifi),
  send(Icons.send),
  settings(Icons.settings);

  const HomeTab(this.icon);

  final IconData icon;

  String get label {
    switch (this) {
      case HomeTab.receive:
        return 'Receive';
      case HomeTab.send:
        return 'Send';
      case HomeTab.settings:
        return 'Settings';
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeTab _currentTab = HomeTab.receive;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _startDeviceDiscovery();
  }

  Future<void> _requestPermissions() async {
    // Request storage permission
    final hasStorage = await PermissionService.requestStoragePermission();
    if (!hasStorage) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required for receiving files'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    // Request location permission
    final hasLocation = await PermissionService.requestLocationPermission();
    if (!hasLocation) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required for device discovery'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _startDeviceDiscovery() async {
    try {
      await DeviceDiscoveryService.start();
      // Start broadcasting presence immediately and discover devices
      await DeviceDiscoveryService.broadcastPresence();
      await DeviceDiscoveryService.discoverDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start device discovery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CP Share'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
        actions: [
          // Show number of discovered devices
          StreamBuilder<List<DeviceInfo>>(
            stream: DeviceDiscoveryService.devicesStream,
            builder: (context, snapshot) {
              final deviceCount = snapshot.data?.length ?? 0;
              if (deviceCount > 0) {
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$deviceCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTab.index,
        children: const [
          ReceiveTab(),
          SendTab(),
          SettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab.index,
        onDestinationSelected: (index) {
          setState(() {
            _currentTab = HomeTab.values[index];
          });
        },
        destinations: HomeTab.values.map((tab) {
          return NavigationDestination(
            icon: Icon(tab.icon),
            label: tab.label,
          );
        }).toList(),
      ),
    );
  }
}