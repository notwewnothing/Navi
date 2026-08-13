import 'package:flutter_test/flutter_test.dart';

import 'package:navi_/main.dart';

void main() {
  testWidgets('NaviApp renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const NaviApp());
    expect(find.text('NAVI'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
