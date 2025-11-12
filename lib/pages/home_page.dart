import 'dart:io';
import 'package:flutter/material.dart';
import 'package:aedove/pages/tabs/receive_tab.dart';
import 'package:aedove/pages/tabs/send_tab.dart';
import 'package:aedove/pages/tabs/settings_tab.dart';
import 'package:aedove/services/permission_service.dart';
import 'package:aedove/services/device_discovery_service.dart';
import 'package:permission_handler/permission_handler.dart';

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
    duration: const Duration(seconds: 2),
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
      // Check if permission is already granted or limited (limited access is acceptable)
      final storageStatus = await Permission.storage.status;

      // Only request if not already granted or limited
      if (!storageStatus.isGranted && !storageStatus.isLimited) {
        final hasStorage = await PermissionService.requestStoragePermission();

        // Only show snackbar if permission was requested and denied (not limited)
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
    }

    // Request location permission on mobile platforms
    if (Platform.isAndroid || Platform.isIOS) {
      // 1. Check current status
      final status = await Permission.locationWhenInUse.status;
      bool hasLocation = status.isGranted || status.isLimited;

      // On iOS, if permission is permanently denied, don't show warning
      // because iOS can use Bonjour/mDNS without location permission
      if (Platform.isIOS && status.isPermanentlyDenied) {
        hasLocation = true; // Treat as OK for iOS
      }

      // 2. If not granted or limited, request permission
      if (!hasLocation) {
        final result = await Permission.locationWhenInUse.request();
        hasLocation = result.isGranted || result.isLimited;

        // On iOS, permanently denied is OK (Bonjour/mDNS doesn't need it)
        if (Platform.isIOS && result.isPermanentlyDenied) {
          hasLocation = true;
        }

        // 3. Show warning only if permission was requested and still not granted/limited
        // For iOS, don't show warning if permanently denied (it's OK)
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
      // If permission was already granted or limited, don't show any snackbar
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
        title: const Text('AeDove'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh Device Discovery',
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
