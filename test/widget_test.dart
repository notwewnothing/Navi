import 'package:flutter_test/flutter_test.dart';

import 'package:navi/main.dart';

void main() {
  testWidgets('NaviApp renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const NaviApp());
    // the wordmark is split per letter so it can resolve one glyph at a time
    expect(find.text('N'), findsOneWidget);
    expect(find.text('HABITS · JOURNAL · SCHEDULE'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
