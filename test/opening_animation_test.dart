import 'package:likhae/core/theme/app_theme.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/shared/widgets/opening_animation_screen.dart';
import 'package:likhae/shared/widgets/app_motion.dart';
import 'package:likhae/features/buyer/home/home_screen.dart';
import 'package:likhae/features/buyer/wishlist/wishlist_screen.dart';
import 'package:likhae/features/buyer/cart/cart_screen.dart';
import 'package:likhae/features/buyer/orders/order_success_screen.dart';
import 'package:likhae/features/buyer/orders/order_tracking_screen.dart';
import 'package:likhae/services/wishlist_service.dart';

class _NoNetwork extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Opening must never create a network client');
  }
}

void main() {
  for (final size in [const Size(320, 568), const Size(640, 360)]) {
    testWidgets('opening fits a $size viewport with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: const EdgeInsets.only(top: 24, bottom: 20),
              viewPadding: const EdgeInsets.only(top: 24, bottom: 20),
              textScaler: TextScaler.linear(2),
            ),
            child: OpeningAnimationScreen(onFinished: () {}),
          ),
        ),
      );
      for (var tick = 0; tick < 30; tick++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        final fit = find.byType(FittedBox).first;
        final bounds = tester.getRect(fit);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(size.width));
        expect(bounds.bottom, lessThanOrEqualTo(size.height - 20));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('deadline completes even when the animation clock is paused', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(home: OpeningAnimationScreen(onFinished: () => completed++)),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 16));
    expect(completed, 1);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets(
    'tour mounts real screens without network or wishlist mutations and settles',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final previous = HttpOverrides.current;
      final network = _NoNetwork();
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = previous);
      final wishlist = Set<int>.of(WishlistService.productIds.value);
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OpeningAnimationScreen(onFinished: () => completed++),
        ),
      );
      for (final phase in <(int, Type)>[
        (1500, BuyerHomeScreen),
        (1200, WishlistScreen),
        (650, CartScreen),
        (700, OrderSuccessScreen),
        (1000, OrderTrackingScreen),
        (1250, AppOpeningContent),
      ]) {
        await tester.pump(Duration(milliseconds: phase.$1 * 2));
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.byType(phase.$2), findsOneWidget);
        expect(tester.takeException(), isNull, reason: "Phase: ${phase.$2}");
      }
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(completed, 1);
      expect(network.attempts, 0);
      expect(WishlistService.productIds.value, wishlist);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      expect(completed, 1);
    },
  );

  testWidgets('skip cancels tour while authentication may still be pending', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OpeningAnimationScreen(onFinished: () => completed++),
      ),
    );
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(completed, 1);
    expect(find.text('Getting things ready…'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(completed, 1);
  });

  testWidgets(
    'reduced motion bypasses tour and early disposal cancels deadline',
    (tester) async {
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: OpeningAnimationScreen(onFinished: () => completed++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(completed, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OpeningAnimationScreen(onFinished: () => completed++),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      expect(completed, 1);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}
