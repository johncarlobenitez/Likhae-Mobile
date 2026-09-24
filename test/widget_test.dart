import 'package:flutter_test/flutter_test.dart';

import 'package:likhae/app.dart';

void main() {
  testWidgets('App smoke test — renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LikhaeApp());
    await tester.pumpAndSettle();

    // The app should build and display something on screen.
    expect(find.byType(LikhaeApp), findsOneWidget);
  });
}
