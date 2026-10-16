import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/rider/rider_api_loader.dart';

Widget page(int? data, Object? error) => Scaffold(
  body: Column(
    children: <Widget>[
      Text('Assignments: $data'),
      if (error != null) const Text('Refresh failed'),
    ],
  ),
);

void main() {
  testWidgets('initial failure shows retry instead of zero assignments', (
    WidgetTester tester,
  ) async {
    final Completer<int> first = Completer<int>();
    final Completer<int> second = Completer<int>();
    int calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderApiLoader<int>(
          refreshInterval: null,
          load: () => ++calls == 1 ? first.future : second.future,
          builder: (context, data, error, refresh) => page(data, error),
        ),
      ),
    );
    expect(find.text('Loading rider data...'), findsOneWidget);
    expect(find.textContaining('Assignments:'), findsNothing);

    first.completeError(Exception('The request timed out.'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load rider data'), findsOneWidget);
    expect(find.text('The request timed out.'), findsOneWidget);
    expect(find.textContaining('Assignments:'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(calls, 2);
    second.complete(3);
    await tester.pumpAndSettle();
    expect(find.text('Assignments: 3'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('refresh preserves data and never overlaps a slow request', (
    WidgetTester tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final Completer<int> slowRefresh = Completer<int>();
    int calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderApiLoader<int>(
          load: () {
            calls++;
            if (calls == 2) return slowRefresh.future;
            return Future<int>.value(calls == 1 ? 3 : 4);
          },
          builder: (context, data, error, refresh) => page(data, error),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 2);
    expect(find.text('Assignments: 3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 2);

    slowRefresh.completeError(Exception('Timeout'));
    await tester.pumpAndSettle();
    expect(find.text('Assignments: 3'), findsOneWidget);
    expect(find.text('Refresh failed'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(calls, 3);
    expect(find.text('Assignments: 4'), findsOneWidget);
    expect(find.text('Refresh failed'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pauses polling in background and refreshes when resumed', (
    WidgetTester tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    int calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderApiLoader<int>(
          load: () async => ++calls,
          builder: (context, data, error, refresh) => page(data, error),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 31));
    expect(calls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, 2);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
    expect(calls, 2);
  });
}
