import 'dart:io';
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

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  HomeTab _currentTab = HomeTab.send;
  late final AnimationController _refreshController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _startDeviceDiscovery();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Request storage permission on Android
      final hasStorage = await PermissionService.requestStoragePermission();
      if (!hasStorage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Storage permission is required for receiving files on Android',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    // Request location permission on mobile platforms
    if (Platform.isAndroid || Platform.isIOS) {
      final hasLocation = await PermissionService.requestLocationPermission();
      if (!hasLocation && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission may be needed for optimal device discovery',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _startDeviceDiscovery() async {
    try {
      // Wait for permissions before starting discovery
      await _requestPermissions();

      // Start device discovery service
      await DeviceDiscoveryService.start();
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

  Future<void> _refreshDiscovery() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    _refreshController.repeat();
    try {
      await DeviceDiscoveryService.stop();
      await DeviceDiscoveryService.start();
    } catch (_) {}
    if (mounted) {
      _refreshController.stop();
      _refreshController.reset();
      setState(() => _refreshing = false);
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
          IconButton(
            tooltip: 'Refresh devices',
            onPressed: _refreshDiscovery,
            icon: RotationTransition(
              turns: _refreshController,
              child: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTab.index,
        children: const [ReceiveTab(), SendTab(), SettingsTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab.index,
        onDestinationSelected: (index) {
          setState(() {
            _currentTab = HomeTab.values[index];
          });
        },
        destinations: HomeTab.values.map((tab) {
          return NavigationDestination(icon: Icon(tab.icon), label: tab.label);
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}
