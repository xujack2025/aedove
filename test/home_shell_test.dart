import 'package:aedove/presentation/pages/home_tab.dart';
import 'package:aedove/presentation/widgets/home/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomeShell renders tabs and forwards nav selection', (
    tester,
  ) async {
    int? selectedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          appBar: AppBar(title: const Text('Home')),
          currentTab: HomeTab.receive,
          onTabSelected: (index) {
            selectedIndex = index;
          },
          tabs: const [
            SizedBox(key: Key('receive-tab')),
            SizedBox(key: Key('send-tab')),
            SizedBox(key: Key('settings-tab')),
          ],
          isBannerAdLoaded: false,
          bannerAd: null,
          overlay: const SizedBox.shrink(),
          floatingActionButton: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pump();

    expect(selectedIndex, 2);
  });
}
