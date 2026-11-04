import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/products/product_details_screen.dart';
import 'package:likhae/shared/widgets/app_motion.dart';
import 'package:likhae/shared/widgets/async_route_builder.dart';

void main() {
  testWidgets(
    'reduced motion leaves loading readable with no repeating frames',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(body: Center(child: AppOpeningContent())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('LIKHAE'), findsOneWidget);
      expect(find.text('SHOP  •  TRACK  •  DELIVER'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading layouts fit narrow screens and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final layout in LoadingLayout.values) {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: RouteLoadingPage(title: 'Loading', layout: layout),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
  });

  testWidgets(
    'loading fade retains entered text when motion preference changes',
    (tester) async {
      Widget page(bool ready, bool reduced) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: AppDataReveal(ready: ready, child: const TextField()),
          ),
        ),
      );
      await tester.pumpWidget(page(false, false));
      await tester.enterText(find.byType(TextField), 'Unsaved draft');
      await tester.pumpWidget(page(true, false));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpWidget(page(true, true));
      expect(find.text('Unsaved draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> showProduct(
    WidgetTester tester,
    ProductPurchaseCallback callback,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailsScreen(
          product: const ProductDetailData(
            id: 123,
            name: 'Woven bag',
            price: 250,
            stock: 4,
          ),
          onAddToCartRequest: callback,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'cart confirmation waits for success and blocks duplicate requests',
    (tester) async {
      final request = Completer<void>();
      var calls = 0;
      await showProduct(tester, (_) {
        calls++;
        return request.future;
      });
      final button = find.widgetWithText(OutlinedButton, 'Add to Cart').last;
      await tester.tap(button);
      await tester.pump();
      expect(calls, 1);
      expect(find.text('Added'), findsNothing);
      await tester.tap(button);
      expect(calls, 1);
      request.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Added'), findsWidgets);
      expect(tester.takeException(), isNull);
      // Disposing during confirmation must cancel its reset timer.
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed cart request never shows a success confirmation', (
    tester,
  ) async {
    final request = Completer<void>();
    await showProduct(tester, (_) => request.future);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add to Cart').last);
    await tester.pump();
    request.completeError(Exception('Connection interrupted'));
    await tester.pumpAndSettle();
    expect(find.text('Added'), findsNothing);
    expect(find.text('Add to Cart'), findsWidgets);
    expect(find.text('Connection interrupted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
