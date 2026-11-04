import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/shared/widgets/app_motion.dart';
import 'package:likhae/shared/widgets/motion_timeline.dart';

void main() {
  testWidgets(
    'loading clock pauses when hidden or backgrounded, then resumes',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      Animation<double>? clock;
      var builds = 0;
      Widget page(bool visible) => MaterialApp(
        home: TickerMode(
          enabled: visible,
          child: AppMotionTimeline(
            duration: const Duration(seconds: 1),
            repeat: true,
            builder: (context, progress) {
              builds++;
              clock = progress;
              return const SizedBox.square(dimension: 24);
            },
          ),
        ),
      );
      await tester.pumpWidget(page(true));
      final initialBuilds = builds;
      await tester.pump(const Duration(milliseconds: 100));
      expect(clock!.value, greaterThan(0));
      expect(
        builds,
        initialBuilds,
        reason: 'Animation frames must not rebuild the surrounding UI.',
      );

      await tester.pumpWidget(page(false));
      final hiddenValue = clock!.value;
      await tester.pump(const Duration(milliseconds: 450));
      expect(clock!.value, hiddenValue);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(page(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(clock!.value, isNot(hiddenValue));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final pausedValue = clock!.value;
      await tester.pump(const Duration(milliseconds: 450));
      expect(clock!.value, pausedValue);
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(clock!.value, isNot(pausedValue));
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('reduced motion stops an active loop immediately', (
    tester,
  ) async {
    Widget page(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: const Scaffold(body: Center(child: AppLoadingIndicator())),
      ),
    );
    await tester.pumpWidget(page(false));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
  });

  testWidgets(
    'favorite only emphasizes a new successful selection, then rests',
    (tester) async {
      Widget page(bool selected, bool loading) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppFavoriteIcon(selected: selected, loading: loading),
          ),
        ),
      );
      await tester.pumpWidget(page(true, false));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(page(false, false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(page(false, true));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(page(true, true));
      await tester.pumpWidget(page(true, false));
      await tester.pump(const Duration(milliseconds: 90));
      final transform = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(AppFavoriteIcon),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(transform.transform.storage[0], greaterThan(1));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(page(true, false));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'drawn confirmation settles and keeps controls usable throughout',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const AppSuccessMark(),
                TextButton(
                  onPressed: () => tapped = true,
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Continue'));
      expect(tapped, isTrue);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
