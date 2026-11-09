import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/shared/widgets/async_route_builder.dart';

Widget contents(BuildContext context, AsyncSnapshot<int> snapshot) => Scaffold(
  body: Column(children: [Text('Value: ${snapshot.data}'), const TextField()]),
);

void main() {
  testWidgets('timed out cart can retry without exposing Dio details', (
    tester,
  ) async {
    var calls = 0;
    final retry = Completer<int>();
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncRouteBuilder<int>(
          errorTitle: 'Cart',
          load: () {
            if (++calls == 1) {
              throw DioException(
                requestOptions: RequestOptions(path: '/buyer/cart'),
                type: DioExceptionType.receiveTimeout,
              );
            }
            return retry.future;
          },
          builder: (context, snapshot) => snapshot.hasData
              ? contents(context, snapshot)
              : const RouteLoadingPage(title: 'Cart'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('The request timed out. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('DioException'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(calls, 2);
    expect(find.text('Try again'), findsNothing);
    retry.complete(42);
    await tester.pumpAndSettle();
    expect(find.text('Value: 42'), findsOneWidget);
  });

  testWidgets(
    'six parent builds: legacy loader calls six times, stable loader once',
    (tester) async {
      var legacyCalls = 0;
      var stableCalls = 0;
      for (var i = 0; i < 6; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: FutureBuilder<int>(
              future: Future.value(++legacyCalls),
              builder: contents,
            ),
          ),
        );
        await tester.pump();
      }
      for (var i = 0; i < 6; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: AsyncRouteBuilder<int>(
              load: () async => ++stableCalls,
              builder: contents,
            ),
          ),
        );
        await tester.pump();
      }
      expect(legacyCalls, 6);
      expect(stableCalls, 1);
    },
  );

  testWidgets('activation revalidates once and preserves entered text', (
    tester,
  ) async {
    var calls = 0;
    final refresh = Completer<int>();
    Widget page(bool active) => MaterialApp(
      home: TickerMode(
        enabled: active,
        child: AsyncRouteBuilder<int>(
          refreshOnActivate: true,
          load: () => ++calls == 1 ? Future.value(1) : refresh.future,
          builder: contents,
        ),
      ),
    );
    await tester.pumpWidget(page(true));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Draft');
    await tester.pumpWidget(page(false));
    await tester.pumpWidget(page(true));
    expect(calls, 2);
    expect(find.text('Draft'), findsOneWidget);
    await tester.pumpWidget(page(true));
    expect(calls, 2);
    refresh.complete(2);
    await tester.pump();
    expect(find.text('Value: 2'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
  });

  testWidgets('changing entity ignores a previous request still in flight', (
    tester,
  ) async {
    final first = Completer<int>();
    final second = Completer<int>();
    Widget page(int id) => MaterialApp(
      home: AsyncRouteBuilder<int>(
        requestKey: id,
        load: () => id == 1 ? first.future : second.future,
        builder: contents,
      ),
    );
    await tester.pumpWidget(page(1));
    await tester.pumpWidget(page(2));
    second.complete(2);
    await tester.pump();
    first.complete(1);
    await tester.pump();
    expect(find.text('Value: 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
