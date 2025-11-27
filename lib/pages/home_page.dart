import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:aedove/pages/tabs/receive_tab.dart';
import 'package:aedove/pages/tabs/send_tab.dart';
import 'package:aedove/pages/tabs/settings_tab.dart';
import 'package:aedove/services/permission_service.dart';
import 'package:aedove/services/device_discovery_service.dart';
import 'package:aedove/constant.dart';
import 'package:aedove/ad_web_view.dart';

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
    duration: const Duration(seconds: 3),
  );
  bool _refreshing = false;

  // ========================= WEBVIEW CONTROLLERS =========================
  // ignore: unused_field
  InAppWebViewController? _adWebViewController;

  // ========================= ADS =========================
  // DEV MODE: Set to false to disable ads during development
  static const bool _enableAds = false;

  // ignore: unused_field
  bool _isExpanded = true;
  bool _naviPlayVisibility = _enableAds;
  bool _popupAlive = true;
  Timer? _visibleTimer;
  Timer? _hiddenTimer;

  late List adLinkDurationData;
  int adLinksIndex = 0;
  bool _navistatus = false;
  String _popupBannerLink = Constant.AD_URL;
  final String _durationAPILink = Constant.AD_API;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _startDeviceDiscovery();
    _fetchLinkDuration();
  }

  // ========================= ADS FLOW (FETCH, ROTATE, TIMERS) =========================

  void _reloadWebViewAD() {
    if (_adWebViewController != null) {
      _adWebViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(_popupBannerLink)),
      );
    }
  }

  void _toggleNaviPlay() {
    setState(() {
      _naviPlayVisibility = false;
      _popupAlive = !_popupAlive;
      if (_popupAlive == true) {
        _isExpanded = true;
        _naviPlayVisibility = true;
      }
    });
  }

  Future<void> _fetchLinkDuration() async {
    // Skip ads if disabled in dev mode
    if (!_enableAds) {
      setState(() {
        _navistatus = false;
      });
      return;
    }

    try {
      final responseData = await http.get(Uri.parse(_durationAPILink));
      if (responseData.statusCode == 200) {
        final jsonData = jsonDecode(responseData.body);
        adLinkDurationData = jsonData['advertisements'];
        if (adLinkDurationData.isEmpty) {
          if (kDebugMode) {
            print("Stopping Ads 1");
          }
          adLinkDurationData = [];
          setState(() {
            _navistatus = false;
          });
          _hiddenTimer?.cancel();
          _visibleTimer?.cancel();
        } else if (_navistatus == false && adLinkDurationData.isNotEmpty) {
          setState(() {
            _navistatus = true;
          });
          _linkChanger();
        } else {
          _linkChanger();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("error occured: $e");
      }
    }
  }

  void _linkChanger() {
    if (adLinkDurationData.isNotEmpty) {
      Map<String, dynamic> bannerItem = adLinkDurationData[adLinksIndex];
      String link = bannerItem['link'];
      int showDuration = (bannerItem['show']);
      int hideDuration = (bannerItem['hide']);
      _popupBannerLink = link;
      _reloadWebViewAD();
      if (_adWebViewController != null) {
        _adWebViewController!.loadUrl(
          urlRequest: URLRequest(url: WebUri(_popupBannerLink)),
        );
      }
      _visibleADTimer(showDuration, hideDuration);
    } else {
      if (kDebugMode) {
        print("Stopping Ads 2");
      }
      adLinkDurationData = [];
      _navistatus = false;
      _hiddenTimer?.cancel();
      _visibleTimer?.cancel();
    }
  }

  void _visibleADTimer(int timerDuration, int hidetimerDuration) {
    _reloadWebViewAD();
    if (kDebugMode) {
      print("Showing: $timerDuration");
    }
    _hiddenTimer?.cancel();
    _visibleTimer = Timer.periodic(Duration(seconds: timerDuration), (timer) {
      _toggleNaviPlay();
      _hiddenADTimer(hidetimerDuration);
    });
  }

  void _hiddenADTimer(int hidetimerDuration) {
    if (kDebugMode) {
      print("Hiding Timer Duration: $hidetimerDuration");
    }
    _isExpanded = false;
    _visibleTimer?.cancel();
    _hiddenTimer = Timer.periodic(Duration(seconds: hidetimerDuration), (
      timer,
    ) {
      _toggleNaviPlay();
      adLinksIndex++;
      if (adLinksIndex == adLinkDurationData.length) {
        _fetchLinkDuration();
        adLinksIndex = 0;
      } else {
        _linkChanger();
      }
      _hiddenTimer?.cancel();
    });
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_naviPlayVisibility == true) {
        _naviPlayVisibility = false;
      } else if (_isExpanded == true) {
        _naviPlayVisibility = true;
      }
    });
  }

  // ignore: unused_element
  Future<void> _launchUrl(Uri url) async {
    try {
      await launchUrl((url), mode: LaunchMode.externalApplication);
    } catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
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
      await Future.wait([
        (() async {
          await DeviceDiscoveryService.stop();
          await DeviceDiscoveryService.start();
        })(),
        Future.delayed(const Duration(milliseconds: 1000)),
      ]);
    } catch (_) {}
    if (mounted) {
      _refreshController.stop();
      setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Aedove',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: _refreshing
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(
                      context,
                    ).colorScheme.inversePrimary.withAlpha((0.5 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: 'Refresh Device Discovery',
              onPressed: _refreshDiscovery,
              icon: RotationTransition(
                turns: _refreshController,
                child: const Icon(Icons.refresh_rounded),
              ),
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
          if (_naviPlayVisibility)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              bottom: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.20,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.1 * 255).round()),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
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
                    _adWebViewController = controller;

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
                  shouldOverrideUrlLoading: (controller, action) async {
                    final url = action.request.url;
                    if (url == null) return NavigationActionPolicy.CANCEL;

                    // Keep your redirect logic
                    if (url.toString().contains("RS-AD-Redirect")) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              WebViewPage(url: url.toString()),
                        ),
                      );
                      await _adWebViewController?.reload();
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.05 * 255).round()),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          height: 70,
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          indicatorColor: Theme.of(context).colorScheme.primaryContainer,
          selectedIndex: _currentTab.index,
          onDestinationSelected: (index) {
            setState(() {
              _currentTab = HomeTab.values[index];
            });
          },
          destinations: HomeTab.values.map((tab) {
            return NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(
                tab.icon,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: tab.label,
            );
          }).toList(),
        ),
      ),
      floatingActionButton: _navistatus
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF303030),
              foregroundColor: const Color(0xFFFFFFFF),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: _toggleExpanded,
              child: _isExpanded
                  ? const Icon(Icons.close_rounded)
                  : const Text(
                      "AD",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            )
          : const SizedBox.shrink(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}
