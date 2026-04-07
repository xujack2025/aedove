import 'dart:io';

import 'package:aedove/ad_web_view.dart';
import 'package:aedove/constant.dart';
import 'package:aedove/pages/tabs/receive_tab.dart';
import 'package:aedove/pages/tabs/send_tab.dart';
import 'package:aedove/pages/tabs/settings_tab.dart';
import 'package:aedove/presentation/bloc/ads/ads_bloc.dart';
import 'package:aedove/presentation/bloc/ads/ads_event.dart';
import 'package:aedove/presentation/bloc/ads/ads_state.dart';
import 'package:aedove/presentation/bloc/discovery/discovery_bloc.dart';
import 'package:aedove/presentation/bloc/discovery/discovery_event.dart';
import 'package:aedove/presentation/bloc/settings/settings_bloc.dart';
import 'package:aedove/presentation/bloc/settings/settings_event.dart';
import 'package:aedove/presentation/bloc/transfer/transfer_bloc.dart';
import 'package:aedove/presentation/bloc/transfer/transfer_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../di/service_locator.dart';

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

  late final DiscoveryBloc _discoveryBloc = sl<DiscoveryBloc>()
    ..add(const DiscoveryStarted());
  late final TransferBloc _transferBloc = sl<TransferBloc>()
    ..add(const TransferStarted());
  late final SettingsBloc _settingsBloc = sl<SettingsBloc>()
    ..add(const SettingsLoaded());
  late final AdsBloc _adsBloc = sl<AdsBloc>()..add(const AdsStarted());

  bool _refreshing = false;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
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

  Future<void> _refreshDiscovery() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    _refreshController.repeat();

    _discoveryBloc.add(const DiscoveryStopped());
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _discoveryBloc.add(const DiscoveryStarted());
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      _refreshController.stop();
      setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _adsBloc,
      child: BlocBuilder<AdsBloc, AdsState>(
        builder: (context, adsState) {
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
                        : Theme.of(context).colorScheme.inversePrimary
                              .withAlpha((0.5 * 255).round()),
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
                if (_isBannerAdLoaded && _bannerAd != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.white,
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      child: AdWidget(ad: _bannerAd!),
                    ),
                  ),
                Positioned(
                  top: _isBannerAdLoaded && _bannerAd != null
                      ? _bannerAd!.size.height.toDouble()
                      : 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IndexedStack(
                    index: _currentTab.index,
                    children: [
                      BlocProvider.value(
                        value: _transferBloc,
                        child: const ReceiveTab(),
                      ),
                      BlocProvider.value(
                        value: _discoveryBloc,
                        child: const SendTab(),
                      ),
                      BlocProvider.value(
                        value: _settingsBloc,
                        child: const SettingsTab(),
                      ),
                    ],
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: adsState.isActive && adsState.isVisible
                      ? MediaQuery.of(context).size.height * 0.20
                      : 0,
                  child: adsState.isActive && adsState.isVisible
                      ? Container(
                          color: Colors.black,
                          child: InAppWebView(
                            key: ValueKey(adsState.currentLink),
                            initialUrlRequest: URLRequest(
                              url: WebUri(adsState.currentLink),
                            ),
                            initialSettings: InAppWebViewSettings(
                              javaScriptEnabled: true,
                              allowsBackForwardNavigationGestures: false,
                              transparentBackground: false,
                            ),
                            shouldOverrideUrlLoading:
                                (controller, action) async {
                                  final url = action.request.url;
                                  if (url == null) {
                                    return NavigationActionPolicy.CANCEL;
                                  }

                                  if (url.toString().contains(
                                    'AEDOVE-AD-Redirect',
                                  )) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            WebViewPage(url: url.toString()),
                                      ),
                                    );
                                    await controller.reload();
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
                    indicatorColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
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
            floatingActionButton: adsState.isActive
                ? FloatingActionButton(
                    backgroundColor: const Color(0xFF303030),
                    foregroundColor: const Color(0xFFFFFFFF),
                    onPressed: () {
                      context.read<AdsBloc>().add(const AdsToggled());
                    },
                    child: adsState.isVisible
                        ? const Icon(Icons.close)
                        : const Text('AD'),
                  )
                : const SizedBox.shrink(),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.miniEndFloat,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _refreshController.dispose();
    _adsBloc.close();
    _discoveryBloc.close();
    _transferBloc.close();
    _settingsBloc.close();
    super.dispose();
  }
}
