import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/theme/app_theme.dart';
import 'package:likhae/core/theme/theme_controller.dart';
import 'package:likhae/features/auth/login_screen.dart';
import 'package:likhae/features/auth/forgot_password_screen.dart';
import 'package:likhae/features/buyer/home/home_screen.dart';
import 'package:likhae/features/buyer/cart/cart_screen.dart';
import 'package:likhae/features/buyer/checkout/checkout_screen.dart';
import 'package:likhae/features/buyer/wishlist/wishlist_screen.dart';
import 'package:likhae/features/buyer/products/products_screen.dart';
import 'package:likhae/features/buyer/orders/orders_screen.dart';
import 'package:likhae/features/buyer/orders/order_tracking_screen.dart';
import 'package:likhae/features/buyer/notifications/notifications_screen.dart';
import 'package:likhae/features/buyer/rewards/rewards_screen.dart';
import 'package:likhae/features/rider/dashboard/dashboard_screen.dart';
import 'package:likhae/features/rider/earnings/rider_earnings_screen.dart';
import 'package:likhae/features/rider/profile/rider_profile_screen.dart';
import 'package:likhae/features/rider/deliveries/rider_delivery_details_screen.dart';
import 'package:likhae/features/rider/deliveries/rider_delivery_models.dart';

const themePages = <String, Widget>{
  'login': LoginScreen(),
  'forgot-password': ForgotPasswordScreen(),
  'home': BuyerHomeScreen(localPreview: true, products: [
    BuyerHomeProduct(id: 1, name: 'Handmade vase', price: 799,
      stock: 4, category: 'Home', sellerName: 'Local shop',
      imageUrl: 'assets/opening/vase.jpg', isFeatured: true),
  ]),
  'products': ProductsScreen(),
  'cart': CartScreen(items: [CartItemData(id: 'test', name: 'Handmade vase',
    category: 'Home', variant: 'Standard', seller: 'Local shop', price: 799,
    quantity: 1, stock: 4, imageUrl: 'assets/opening/vase.jpg')]),
  'checkout': CheckoutScreen(checkoutToken: 'test', items: [], addresses: [], couriersBySeller: {}),
  'wishlist': WishlistScreen(products: [WishlistProduct(id: 1, name: 'Handmade vase',
    price: 799, imageUrl: 'assets/opening/vase.jpg', stock: 4)]),
  'orders': OrdersScreen(showProductPreviewWhenEmpty: false),
  'tracking': OrderTrackingScreen(order: BuyerOrderData(id: 'test',
    status: 'to-receive', statusLabel: 'Out for delivery', payment: 'Cash',
    products: [], total: 799, buyerName: 'Customer', shippingAddress: 'Pila, Laguna',
    isPreview: true), previewMap: SizedBox()),
  'notifications': NotificationsScreen(),
  'rewards': RewardsScreen(),
  'rider-dashboard': RiderDashboardScreen(riderName: 'Alex', stats: [
    RiderDashboardStatData(label: 'Deliveries', value: 4),
  ]),
  'rider-earnings': RiderEarningsScreen(earningsRows: [
    RiderEarningRowData(date: 'Nov 2', reference: 'Delivery', amount: '100', status: 'paid'),
  ]),
  'rider-profile': RiderProfileScreen(),
  'rider-delivery': RiderDeliveryDetailsScreen(delivery: RiderDeliveryData(
    id: 1, trackingCode: 'TEST-001', buyerName: 'Customer', contact: '',
    address: 'Pila, Laguna', amount: 799, status: 'out_for_delivery',
    statusLabel: 'Out for delivery', isPreview: true)),
};

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final entry in themePages.entries) {
    testWidgets('${entry.key} follows local theme on an already mounted screen', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final oldMode = ThemeController.instance.value;
      ThemeController.instance.setLightMode();
      addTearDown(() => ThemeController.instance.value = oldMode);
      Widget page(ThemeMode mode) => MaterialApp(
        theme: AppTheme.lightTheme, darkTheme: AppTheme.darkTheme, themeMode: mode,
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: entry.value,
      );
      await tester.pumpWidget(page(ThemeMode.light));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final before = tester.element(find.byWidget(entry.value));
      await tester.pumpWidget(page(ThemeMode.dark));
      await tester.pumpAndSettle();
      expect(tester.element(find.byWidget(entry.value)), same(before));
      expect(tester.takeException(), isNull);
      const lightSurfaces = {0xFFF6F4F1,0xFFFBF7F2,0xFFFFFDF9,0xFFFFFEFC,
        0xFFF6EFE7,0xFFF0ECE8,0xFFFFFFFF,0xFFF7F2E9,0xFFFFFCF8};
      final leaks = <String>[];
      void check(Color? color, String where) {
        if (color != null && lightSurfaces.contains(color.toARGB32())) leaks.add('$where: $color');
      }
      for (final widget in tester.allWidgets) {
        if (widget is Scaffold) check(widget.backgroundColor, 'Scaffold');
        if (widget is Container) {
          check(widget.color, 'Container');
          if (widget.decoration case final BoxDecoration decoration) check(decoration.color, 'Container decoration');
        }
        if (widget is Material) check(widget.color, 'Material');
      }
      expect(leaks, isEmpty, reason: '${entry.key} must not retain light surfaces in dark mode');
      await tester.pumpWidget(page(ThemeMode.light));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('toggle leaves system dark mode for light mode', (tester) async {
    final controller = ThemeController.instance;
    final previous = controller.value;
    addTearDown(() { controller.value = previous; tester.platformDispatcher.clearPlatformBrightnessTestValue(); });
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    controller.setSystemMode();
    controller.toggleTheme();
    expect(controller.value, ThemeMode.light);
  });
}
