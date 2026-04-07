import 'package:aedove/presentation/widgets/settings/settings_info_tile.dart';
import 'package:aedove/presentation/widgets/settings/settings_switch_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Settings widgets', () {
    testWidgets('SettingsInfoTile renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsInfoTile(
              icon: Icons.info,
              iconColor: Colors.blue,
              title: 'Device Name',
              subtitle: const Text('My Device'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      );

      expect(find.text('Device Name'), findsOneWidget);
      expect(find.text('My Device'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('SettingsSwitchTile invokes onChanged', (tester) async {
      var changedValue = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSwitchTile(
              value: false,
              title: 'Notifications',
              subtitle: 'Show alerts for file transfers',
              onChanged: (value) {
                changedValue = value;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      expect(changedValue, isTrue);
    });
  });
}
