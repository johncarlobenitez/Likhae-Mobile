import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../features/auth/login_screen.dart';
import '../models/auth_user_model.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/wishlist_service.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/buyer/home/home_screen.dart';
import '../features/buyer/cart/cart_screen.dart';
import '../features/buyer/checkout/checkout_screen.dart';
import '../features/buyer/orders/orders_screen.dart';
import '../features/buyer/orders/order_tracking_screen.dart';
import '../features/buyer/notifications/notifications_screen.dart';
import '../features/buyer/products/product_details_screen.dart';
import '../features/buyer/products/products_screen.dart';
import '../features/buyer/messages/messages_screen.dart';
import '../features/buyer/profile/account_screen.dart';
import '../features/buyer/rewards/rewards_screen.dart';
import '../features/buyer/wishlist/wishlist_screen.dart';
import '../features/rider/dashboard/dashboard_screen.dart';
import '../features/rider/scanner/scanner_screen.dart';
import '../shared/widgets/buyer_navigation.dart';

void safeBack(BuildContext context, {String fallback = '/login'}) {
  if (context.canPop()) {
    context.pop();
    return;
  }

  context.go(fallback);
}

ProductDetailData _toProductDetailFromHome(BuyerHomeProduct product) {
  final String? imageUrl = product.imageUrl;

  return ProductDetailData(
    id: product.id,
    name: product.name,
    slug: product.slug,
    category: product.category,
    imageUrl: imageUrl == null || imageUrl.trim().isEmpty
        ? null
        : AppConfig.resolveMediaUrl(imageUrl),
    price: product.price,
    originalPrice: product.originalPrice,
    stock: product.stock ?? 0,
    rating: product.rating,
    soldCount: product.soldCount,
    sellerName: product.sellerName,
    sellerSlug: product.sellerSlug,
    wishlisted: product.wishlisted,
  );
}

ProductDetailData _toProductDetail(BuyerProduct product) {
  final String? imageUrl = product.imageUrl;

  return ProductDetailData(
    id: product.id,
    name: product.name,
    slug: product.slug,
    category: product.category,
    imageUrl: imageUrl == null || imageUrl.trim().isEmpty
        ? null
        : AppConfig.resolveMediaUrl(imageUrl),
    price: product.price,
    originalPrice: product.originalPrice,
    stock: product.stock ?? 0,
    rating: product.rating,
    soldCount: product.soldCount,
    sellerName: product.sellerName,
    sellerSlug: product.sellerSlug,
    wishlisted: product.wishlisted,
  );
}

Widget _buyerNavigationFrame(
  BuildContext context, {
  required int currentIndex,
  required Widget child,
}) {
  return BuyerNavigationFrame(
    currentIndex: currentIndex,
    onHome: () => context.go('/buyer/home'),
    onOrders: () => context.go('/buyer/orders'),
    onMessages: () => context.go('/buyer/messages'),
    onProfile: () => context.go('/buyer/profile'),
    child: child,
  );
}

CheckoutItemData _toCheckoutItem(
  ProductDetailData product,
  ProductPurchaseRequest request,
) {
  return CheckoutItemData(
    id: product.id,
    productId: request.productId,
    sellerId: 0,
    seller: product.sellerName ?? 'LIKHAE Seller',
    name: product.name,
    variant: request.variant ?? '',
    productVariantId: request.productVariationId,
    imageUrl: product.imageUrl,
    price: product.price,
    quantity: request.quantity,
  );
}

Future<void> _handleLogin(
  BuildContext context, {
  required String email,
  required String password,
  required bool rememberMe,
  required VoidCallback onError,
}) async {
  try {
    final Map<String, dynamic> payload = await AuthService.login(
      email: email,
      password: password,
      deviceName: 'LIKHAE Flutter',
    );

    final dynamic responseData = payload['data'];
    final dynamic userPayload =
        payload['user'] ??
        (responseData is Map
            ? responseData['user'] ?? responseData
            : responseData);
    if (userPayload is! Map<String, dynamic>) {
      throw const FormatException('Login response is missing user data.');
    }

    final AuthUserModel user = AuthUserModel.fromJson(userPayload);
    final List<String> mobileRoles = user.mobileRoles;

    if (context.mounted) {
      if (mobileRoles.contains('rider') && !mobileRoles.contains('buyer')) {
        context.go('/rider/dashboard');
        return;
      }

      context.go('/buyer/home');
    }
  } catch (error) {
    onError();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',

  routes: [
    // ── Auth ─────────────────────────────────────────────────────────────────
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (BuildContext context, GoRouterState state) {
        return LoginScreen(
          onRegister: () => context.push('/register'),
          onForgotPassword: () => context.push('/forgot-password'),
          onSignIn: (String email, String password, bool rememberMe) async {
            await _handleLogin(
              context,
              email: email,
              password: password,
              rememberMe: rememberMe,
              onError: () {},
            );
          },
          onContinueAsBuyer: () => context.push('/buyer/home'),
          onContinueAsRider: () => context.push('/rider/dashboard'),
        );
      },
    ),

    GoRoute(
      path: '/register',
      name: 'register',
      builder: (BuildContext context, GoRouterState state) {
        return const RegisterScreen();
      },
    ),

    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (BuildContext context, GoRouterState state) {
        return const ForgotPasswordScreen();
      },
    ),

    // ── Buyer ─────────────────────────────────────────────────────────────────
    GoRoute(
      path: '/buyer/home',
      name: 'buyer-home',
      builder: (BuildContext context, GoRouterState state) {
        return BuyerHomeScreen(
          onSearch: () => context.push('/buyer/products'),
          onBrowseProducts: () => context.push('/buyer/products'),
          onViewOrders: () => context.push('/buyer/orders'),
          onWishlist: () => context.push('/buyer/wishlist'),
          onCart: () => context.push('/buyer/cart'),
          onNotifications: () => context.push('/buyer/notifications'),
          onMessages: () => context.push('/buyer/messages'),
          onProfile: () => context.push('/buyer/profile'),
          onVouchers: () => context.push('/buyer/rewards'),
          onViewAllCategories: () => context.push('/buyer/products'),
          onCategorySelected: (String categorySlug) {
            context.push('/buyer/products');
          },
          onProductSelected: (BuyerHomeProduct product) {
            context.push(
              '/buyer/product-details',
              extra: _toProductDetailFromHome(product),
            );
          },
          onWishlistProduct: (BuyerHomeProduct product) async {
            await WishlistService.toggleProduct(product.id);
          },
        );
      },
    ),

    GoRoute(
      path: '/buyer/product-details',
      name: 'buyer-product-details',
      builder: (BuildContext context, GoRouterState state) {
        final dynamic extra = state.extra;
        final ProductDetailData product = extra is ProductDetailData
            ? extra
            : extra is BuyerHomeProduct
            ? _toProductDetailFromHome(extra)
            : _toProductDetail(extra as BuyerProduct);

        return ProductDetailsScreen(
          product: product,
          relatedProducts: const [],
          onBack: () => safeBack(context, fallback: '/buyer/products'),
          onCart: () => context.push('/buyer/cart'),
          onBuyNowRequest: (ProductPurchaseRequest request) async {
            if (context.mounted) {
              context.push(
                '/buyer/checkout',
                extra: <CheckoutItemData>[_toCheckoutItem(product, request)],
              );
            }
          },
          onViewStore: (ProductDetailData detail) {
            context.push('/buyer/home');
          },
        );
      },
    ),

    GoRoute(
      path: '/buyer/products',
      name: 'buyer-products',
      builder: (BuildContext context, GoRouterState state) {
        return ProductsScreen(
          onBack: () => safeBack(context, fallback: '/buyer/home'),
          onCart: () => context.push('/buyer/cart'),
          onNotifications: () => context.push('/buyer/notifications'),
          onProductSelected: (BuyerProduct product) {
            context.push(
              '/buyer/product-details',
              extra: _toProductDetail(product),
            );
          },
          onWishlistProduct: (BuyerProduct product) async {
            await WishlistService.toggleProduct(product.id);
          },
        );
      },
    ),

    GoRoute(
      path: '/buyer/wishlist',
      name: 'buyer-wishlist',
      builder: (BuildContext context, GoRouterState state) {
        return WishlistScreen(
          onBack: () => safeBack(context, fallback: '/buyer/home'),
          onContinueShopping: () => context.push('/buyer/home'),
          onCart: () => context.push('/buyer/cart'),
          onNotifications: () => context.push('/buyer/notifications'),
        );
      },
    ),

    GoRoute(
      path: '/buyer/notifications',
      name: 'buyer-notifications',
      builder: (BuildContext context, GoRouterState state) {
        return NotificationsScreen(
          onBack: () => safeBack(context, fallback: '/buyer/home'),
          onNotificationTap: (notification) async {
            // Route based on the notification type when the buyer taps one.
            switch (notification.type) {
              case BuyerNotificationType.orders:
                context.push('/buyer/orders');
                break;
              case BuyerNotificationType.messages:
                context.push('/buyer/messages');
                break;
              case BuyerNotificationType.rewards:
                context.push('/buyer/home');
                break;
              case BuyerNotificationType.account:
                context.push('/buyer/home');
                break;
              case BuyerNotificationType.general:
                context.push('/buyer/home');
                break;
            }
          },
        );
      },
    ),

    GoRoute(
      path: '/buyer/cart',
      name: 'buyer-cart',
      builder: (BuildContext context, GoRouterState state) {
        return CartScreen(
          onBack: () => safeBack(context, fallback: '/buyer/home'),
          onContinueShopping: () => context.push('/buyer/home'),
          onChangeAddress: () => context.push('/buyer/home'),
        );
      },
    ),

    GoRoute(
      path: '/buyer/checkout',
      name: 'buyer-checkout',
      builder: (BuildContext context, GoRouterState state) {
        final dynamic extra = state.extra;
        final List<CheckoutItemData> items = extra is List
            ? extra.whereType<CheckoutItemData>().toList(growable: false)
            : const <CheckoutItemData>[];

        return CheckoutScreen(
          checkoutToken: 'offline-layout-checkout',
          items: items,
          addresses: const <CheckoutAddressData>[],
          couriersBySeller: const <int, List<CheckoutCourierOption>>{},
          initialRecipientName: '',
          initialContactNumber: '',
          onBackToCart: () => context.go('/buyer/cart'),
        );
      },
    ),

    GoRoute(
      path: '/buyer/rewards',
      name: 'buyer-rewards',
      builder: (BuildContext context, GoRouterState state) {
        return RewardsScreen(
          onBack: () => safeBack(context, fallback: '/buyer/home'),
          onBrowseProducts: () => context.push('/buyer/products'),
        );
      },
    ),

    GoRoute(
      path: '/buyer/orders',
      name: 'buyer-orders',
      builder: (BuildContext context, GoRouterState state) {
        return _buyerNavigationFrame(
          context,
          currentIndex: 1,
          child: FutureBuilder<List<BuyerOrderData>>(
            future: OrderService.fetchMyOrders(),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<BuyerOrderData>> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return OrdersScreen(
                    orders: snapshot.data ?? const <BuyerOrderData>[],
                    buyerNotice: snapshot.hasError
                        ? 'Orders could not be loaded. Pull down to try again.'
                        : null,
                    onBack: () => safeBack(context, fallback: '/buyer/home'),
                    onShopProducts: () => context.push('/buyer/products'),
                    onTrackOrder: (BuyerOrderData order) {
                      context.push('/buyer/order-tracking', extra: order);
                    },
                  );
                },
          ),
        );
      },
    ),

    GoRoute(
      path: '/buyer/order-tracking',
      name: 'buyer-order-tracking',
      builder: (BuildContext context, GoRouterState state) {
        final dynamic extra = state.extra;
        if (extra is! BuyerOrderData) {
          return const Scaffold(
            body: Center(child: Text('Tracking information is unavailable.')),
          );
        }

        return OrderTrackingScreen(
          order: extra,
          onBack: () => safeBack(context, fallback: '/buyer/orders'),
        );
      },
    ),

    GoRoute(
      path: '/buyer/messages',
      name: 'buyer-messages',
      builder: (BuildContext context, GoRouterState state) {
        return _buyerNavigationFrame(
          context,
          currentIndex: 2,
          child: MessagesScreen(
            onBack: () => safeBack(context, fallback: '/buyer/home'),
          ),
        );
      },
    ),

    GoRoute(
      path: '/buyer/profile',
      name: 'buyer-profile',
      builder: (BuildContext context, GoRouterState state) {
        return _buyerNavigationFrame(
          context,
          currentIndex: 3,
          child: FutureBuilder<AuthUserModel>(
            future: AuthService.getCurrentUser(),
            builder:
                (BuildContext context, AsyncSnapshot<AuthUserModel> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return Scaffold(
                      appBar: AppBar(
                        title: const Text('Profile'),
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () =>
                              safeBack(context, fallback: '/buyer/home'),
                        ),
                      ),
                      body: const Center(
                        child: Text('Unable to load your profile.'),
                      ),
                    );
                  }

                  final AuthUserModel user = snapshot.data!;

                  return AccountScreen(
                    profile: BuyerProfileData(
                      name: user.name,
                      email: user.email ?? '',
                      phone: user.contactNumber ?? '',
                    ),
                    onBack: () => safeBack(context, fallback: '/buyer/home'),
                  );
                },
          ),
        );
      },
    ),

    // ── Rider ─────────────────────────────────────────────────────────────────
    GoRoute(
      path: '/rider/dashboard',
      name: 'rider-dashboard',
      builder: (BuildContext context, GoRouterState state) {
        return const RiderDashboardScreen();
      },
    ),

    GoRoute(
      path: '/rider/scanner',
      name: 'rider-scanner',
      builder: (BuildContext context, GoRouterState state) {
        return const RiderScannerScreen();
      },
    ),
  ],

  errorBuilder: (BuildContext context, GoRouterState state) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 56),

              const SizedBox(height: 16),

              const Text(
                'Page not found',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 8),

              Text(state.uri.toString(), textAlign: TextAlign.center),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  context.go('/login');
                },
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
