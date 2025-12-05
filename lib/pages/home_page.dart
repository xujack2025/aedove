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
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

  void _reloadWebViewAD() {
    if (_adWebViewController != null) {
      _adWebViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(_popupBannerLink)),
      );
    }
  }

  // ========================= ADS =========================
  final bool _loginStop = false;
  bool _isExpandedAd = true;
  bool _naviPlayVisibility = true;
  bool _popupAlive = true;

  Timer? _visibleTimer;
  Timer? _hiddenTimer;

  late List adLinkDurationData;
  int adLinksIndex = 0;
  bool _adnavistatus = false;

  late String _popupBannerLink = Constant.AD_URL;
  String durationAPILink = Constant.AD_API;

  // Google AdMob Banner Ad
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _fetchLinkDuration();
    _loadBannerAd();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _hasInitialized = true;
      _startDeviceDiscovery();
    }
  }

  void _loadBannerAd() {
    // Only load banner ads on supported platforms (Android and iOS)
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('Banner ads not supported on this platform');
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: Constant.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
          debugPrint('Banner ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
          setState(() {
            _isBannerAdLoaded = false;
          });
        },
      ),
    )..load();
  }

  // ========================= ADS FLOW (FETCH, ROTATE, TIMERS) =========================
  void _toggleNaviPlay() {
    if (!_loginStop) {
      setState(() {
        _naviPlayVisibility = false;
        _popupAlive = !_popupAlive;
        if (_popupAlive == true) {
          _isExpandedAd = true;
          _naviPlayVisibility = true;
        }
      });
    }
  }

  Future<void> _fetchLinkDuration() async {
    try {
      final responseData = await http.get(Uri.parse(durationAPILink));
      if (responseData.statusCode == 200) {
        final jsonData = jsonDecode(responseData.body);
        adLinkDurationData = jsonData['advertisements'];
        if (adLinkDurationData.isEmpty) {
          debugPrint("Stopping Ads 1");
          adLinkDurationData = [];
          setState(() {
            _adnavistatus = false;
          });
          _hiddenTimer?.cancel();
          _visibleTimer?.cancel();
        } else if (_adnavistatus == false && adLinkDurationData.isNotEmpty) {
          setState(() {
            _adnavistatus = true;
          });
          _linkChanger();
        } else {
          _linkChanger();
        }
      }
    } catch (e) {
      debugPrint("error occured: $e");
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
      debugPrint("Stopping Ads 2");
      adLinkDurationData = [];
      _adnavistatus = false;
      _hiddenTimer?.cancel();
      _visibleTimer?.cancel();
    }
  }

  void _visibleADTimer(int timerDuration, int hidetimerDuration) {
    _reloadWebViewAD();
    debugPrint("Showing: $timerDuration");
    _hiddenTimer?.cancel();
    _visibleTimer = Timer.periodic(Duration(seconds: timerDuration), (timer) {
      if (!_loginStop) {
        _toggleNaviPlay();
        _hiddenADTimer(hidetimerDuration);
      }
    });
  }

  void _hiddenADTimer(int hidetimerDuration) {
    debugPrint("Hiding: $hidetimerDuration");
    _isExpandedAd = false;
    _visibleTimer?.cancel();
    _hiddenTimer = Timer.periodic(Duration(seconds: hidetimerDuration), (
      timer,
    ) {
      if (!_loginStop) {
        _toggleNaviPlay();
        adLinksIndex++;
        if (adLinksIndex == adLinkDurationData.length) {
          _fetchLinkDuration();
          adLinksIndex = 0;
        } else {
          _linkChanger();
        }
        _hiddenTimer?.cancel();
      }
    });
  }

  void _toggleExpandedAd() {
    setState(() {
      _isExpandedAd = !_isExpandedAd;
      if (_naviPlayVisibility == true) {
        _naviPlayVisibility = false;
      } else if (_isExpandedAd == true) {
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
          // ---- Ads Section ----
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            bottom: 0,
            left: 0,
            right: 0,
            height: _adnavistatus
                ? _naviPlayVisibility
                      ? MediaQuery.of(context).size.height * 0.20
                      : 0
                : 0,
            child: _naviPlayVisibility
                ? Container(
                    color: Colors.black, // backgroundColor replacement
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(_popupBannerLink),
                      ),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        allowsBackForwardNavigationGestures: false,
                        transparentBackground: false,
                      ),
                      onWebViewCreated: (controller) {
                        _adWebViewController = controller;
                      },
                      shouldOverrideUrlLoading: (controller, action) async {
                        final url = action.request.url;
                        if (url == null) return NavigationActionPolicy.CANCEL;

                        // Keep your redirect logic
                        if (url.toString().contains("AEDOVE-AD-Redirect")) {
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
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AdMob Banner Ad
          if (_isBannerAdLoaded && _bannerAd != null)
            Container(
              color: Colors.white,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          // Navigation Bar
          Container(
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
        ],
      ),
      floatingActionButton: _adnavistatus
          ? FloatingActionButton(
              backgroundColor: Color(0xFF303030),
              foregroundColor: Color(0xFFFFFFFF),
              onPressed: _toggleExpandedAd,
              child: _isExpandedAd ? Icon(Icons.close) : Text("AD"),
            )
          : SizedBox.shrink(),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _refreshController.dispose();
    super.dispose();
  }
}
