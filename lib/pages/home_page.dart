import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:aedove/pages/tabs/receive_tab.dart';
import 'package:aedove/pages/tabs/send_tab.dart';
import 'package:aedove/pages/tabs/settings_tab.dart';
import 'package:aedove/services/permission_service.dart';
import 'package:aedove/services/device_discovery_service.dart';
import 'package:aedove/constant.dart';

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

  // ========================= WEBVIEW CONTROLLERS =========================
  // ignore: unused_field
  InAppWebViewController? _webViewController;

  // ========================= ADS =========================
  // ignore: unused_field
  bool _isExpanded = true;
  bool _naviPlayVisibility = false;
  bool _popupAlive = true;
  Timer? _visibilityTimer;
  Timer? _closerTimer;
  final String _popupBannerLink = Constant.AD_URL;
  final String _durationAPILink = Constant.AD_API;
  int _hideDurationSeconds = 60;
  int _showDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _startDeviceDiscovery();
    _fetchDurationData();
    _startVisibilityTimer();
  }

  // ========================= ADS FLOW (FETCH, ROTATE, TIMERS) =========================
  void _toggleNaviPlay() {
    _fetchDurationData();
    setState(() {
      _naviPlayVisibility = false;
      _popupAlive = !_popupAlive;
      if (_popupAlive == true) {
        _isExpanded = true;
        _naviPlayVisibility = true;
      }
    });
  }

  void _startVisibilityTimer() {
    _fetchDurationData();
    _closerTimer?.cancel();
    _visibilityTimer = Timer.periodic(Duration(seconds: _showDurationSeconds), (
      timer,
    ) {
      _toggleNaviPlay();
      _startCloseTimer();
    });
  }

  void _startCloseTimer() {
    _fetchDurationData();
    _visibilityTimer?.cancel();
    _closerTimer = Timer.periodic(Duration(seconds: _hideDurationSeconds), (
      timer,
    ) {
      _toggleNaviPlay();
      _startVisibilityTimer();
    });
  }

  Future<void> _fetchDurationData() async {
    try {
      final response = await http.get(Uri.parse(_durationAPILink));
      // print(response.body);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        _hideDurationSeconds = jsonData['hideDuration'];
        _showDurationSeconds = jsonData['showDuration'];
      } else {
        _hideDurationSeconds = 150;
        _showDurationSeconds = 15;
      }
    } catch (e) {
      _hideDurationSeconds = 150;
      _showDurationSeconds = 15;
    }
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
  }

  Future<void> _startDeviceDiscovery() async {
    try {
      // Wait for permissions before starting discovery
      await _requestPermissions();

      // Start device discovery service
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
      body: Stack(
        children: [
          // Main content
          IndexedStack(
            index: _currentTab.index,
            children: const [ReceiveTab(), SendTab(), SettingsTab()],
          ),

          // Animated ad banner at the bottom
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            bottom: _naviPlayVisibility
                ? 0
                : -MediaQuery.of(context).size.height * 0.20,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.20,
            child: IgnorePointer(
              ignoring: !_naviPlayVisibility,
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_popupBannerLink)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  supportZoom: false,
                  disableHorizontalScroll: true,
                  disableVerticalScroll: true,
                  transparentBackground: true,
                  // Add these settings to prevent keyboard popup
                  disableContextMenu: true,
                  // iOS specific settings
                  allowsInlineMediaPlayback: true,
                  suppressesIncrementalRendering: true,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;

                  // Inject JavaScript to prevent all input focus
                  controller.evaluateJavascript(
                    source: """
                      (function() {
                        // Prevent focus on all input elements
                        document.addEventListener('click', function(e) {
                          if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
                            e.preventDefault();
                            e.stopPropagation();
                            e.target.blur();
                            return false;
                          }
                        }, true);
                        
                        document.addEventListener('touchstart', function(e) {
                          if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
                            e.preventDefault();
                            e.stopPropagation();
                            e.target.blur();
                            return false;
                          }
                        }, true);
                        
                        document.addEventListener('focus', function(e) {
                          if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
                            e.target.blur();
                          }
                        }, true);
                      })();
                    """,
                  );
                },
                onLoadStop: (controller, url) async {
                  // Remove focus from any input fields after page loads
                  await controller.evaluateJavascript(
                    source: """
                      (function() {
                        var inputs = document.querySelectorAll('input, textarea');
                        inputs.forEach(function(input) {
                          input.setAttribute('readonly', 'readonly');
                          input.setAttribute('disabled', 'disabled');
                          input.style.pointerEvents = 'none';
                          input.blur();
                        });
                        if (document.activeElement) {
                          document.activeElement.blur();
                        }
                      })();
                    """,
                  );
                },
              ),
            ),
          ),
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
          return NavigationDestination(icon: Icon(tab.icon), label: tab.label);
        }).toList(),
      ),
      floatingActionButton: _naviPlayVisibility
          ? FloatingActionButton(
              backgroundColor: Colors.transparent,
              onPressed: () {
                _closerTimer?.cancel();
                _visibilityTimer?.cancel();
                setState(() {
                  _naviPlayVisibility = false; // Hide ad immediately
                });
                _startCloseTimer(); // Restart the hide timer
              },
              mini: true,
              child: const Icon(Icons.close_rounded),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}
