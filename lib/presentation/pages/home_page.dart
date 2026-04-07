import 'dart:io';

import 'package:aedove/ad_web_view.dart';
import 'package:aedove/constant.dart';
import 'package:aedove/presentation/pages/home_tab.dart';
import 'package:aedove/presentation/pages/tabs/receive_tab.dart';
import 'package:aedove/presentation/pages/tabs/send_tab.dart';
import 'package:aedove/presentation/pages/tabs/settings_tab.dart';
import 'package:aedove/presentation/bloc/ads/ads_bloc.dart';
import 'package:aedove/presentation/bloc/ads/ads_event.dart';
import 'package:aedove/presentation/bloc/ads/ads_state.dart';
import 'package:aedove/presentation/bloc/discovery/discovery_bloc.dart';
import 'package:aedove/presentation/bloc/discovery/discovery_event.dart';
import 'package:aedove/presentation/bloc/settings/settings_bloc.dart';
import 'package:aedove/presentation/bloc/settings/settings_event.dart';
import 'package:aedove/presentation/bloc/transfer/transfer_bloc.dart';
import 'package:aedove/presentation/bloc/transfer/transfer_event.dart';
import 'package:aedove/presentation/widgets/home/home_ad_overlay.dart';
import 'package:aedove/presentation/widgets/home/home_app_bar.dart';
import 'package:aedove/presentation/widgets/home/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../di/service_locator.dart';

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

    // Keep the discovery service alive while refreshing to avoid socket churn
    // and transient disconnects on desktop platforms.
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
          return HomeShell(
            appBar: HomeAppBar(
              isRefreshing: _refreshing,
              refreshAnimation: _refreshController,
              onRefresh: _refreshDiscovery,
            ),
            currentTab: _currentTab,
            onTabSelected: (index) {
              setState(() {
                _currentTab = HomeTab.values[index];
              });
            },
            tabs: [
              BlocProvider.value(
                value: _transferBloc,
                child: const ReceiveTab(),
              ),
              BlocProvider.value(value: _discoveryBloc, child: const SendTab()),
              BlocProvider.value(
                value: _settingsBloc,
                child: const SettingsTab(),
              ),
            ],
            isBannerAdLoaded: _isBannerAdLoaded,
            bannerAd: _bannerAd,
            overlay: HomeAdOverlay(
              isVisible: adsState.isActive && adsState.isVisible,
              currentLink: adsState.currentLink,
              height: MediaQuery.of(context).size.height * 0.20,
              onRedirect: (url, controller) async {
                if (url == null) {
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WebViewPage(url: url.toString()),
                  ),
                );
                await controller.reload();
              },
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
