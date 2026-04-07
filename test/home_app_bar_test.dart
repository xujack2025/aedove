import 'package:aedove/presentation/widgets/home/home_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomeAppBar triggers refresh callback', (tester) async {
    var refreshed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: HomeAppBar(
            isRefreshing: false,
            refreshAnimation: const AlwaysStoppedAnimation<double>(0),
            onRefresh: () {
              refreshed = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();

    expect(refreshed, isTrue);
  });
}
