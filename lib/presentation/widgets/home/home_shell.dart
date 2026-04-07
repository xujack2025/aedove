import 'package:aedove/presentation/pages/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({
    super.key,
    required this.appBar,
    required this.currentTab,
    required this.onTabSelected,
    required this.tabs,
    required this.isBannerAdLoaded,
    required this.bannerAd,
    required this.overlay,
    required this.floatingActionButton,
  });

  final PreferredSizeWidget appBar;
  final HomeTab currentTab;
  final ValueChanged<int> onTabSelected;
  final List<Widget> tabs;
  final bool isBannerAdLoaded;
  final BannerAd? bannerAd;
  final Widget overlay;
  final Widget floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final hasBanner =
        isBannerAdLoaded &&
        bannerAd != null &&
        bannerAd!.size.width > 0 &&
        bannerAd!.size.height > 0;

    return Scaffold(
      appBar: appBar,
      body: Column(
        children: [
          if (hasBanner)
            Container(
              color: Colors.white,
              width: double.infinity,
              height: bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: bannerAd!),
            ),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(index: currentTab.index, children: tabs),
                overlay,
              ],
            ),
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
              indicatorColor: Theme.of(context).colorScheme.primaryContainer,
              selectedIndex: currentTab.index,
              onDestinationSelected: onTabSelected,
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
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }
}
