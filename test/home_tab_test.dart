import 'package:aedove/presentation/pages/home_tab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HomeTab labels are stable', () {
    expect(HomeTab.receive.label, 'Receive');
    expect(HomeTab.send.label, 'Send');
    expect(HomeTab.settings.label, 'Settings');
  });
}
