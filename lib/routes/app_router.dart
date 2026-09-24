import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../features/auth/login_screen.dart';
import '../models/auth_user_model.dart';
import '../services/auth_service.dart';
import '../services/wishlist_service.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/buyer/home/home_screen.dart';
import '../features/buyer/cart/cart_screen.dart';
import '../features/buyer/orders/orders_screen.dart';
import '../features/buyer/notifications/notifications_screen.dart';
import '../features/buyer/products/product_details_screen.dart';
import '../features/buyer/products/products_screen.dart';
import '../features/buyer/messages/messages_screen.dart';
import '../features/buyer/rewards/rewards_screen.dart';
import '../features/buyer/wishlist/wishlist_screen.dart';
import '../features/rider/dashboard/dashboard_screen.dart';
import '../features/rider/scanner/scanner_screen.dart';

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

    final dynamic userPayload = payload['user'];
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
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
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
          onBrowseProducts: () => context.push('/buyer/products'),
          onViewOrders: () => context.push('/buyer/orders'),
          onWishlist: () => context.push('/buyer/wishlist'),
          onCart: () => context.push('/buyer/cart'),
          onNotifications: () => context.push('/buyer/notifications'),
          onMessages: () => context.push('/buyer/messages'),
          onVouchers: () => context.push('/buyer/rewards'),
          onViewAllCategories: () => context.push('/buyer/products'),
          onCategorySelected: (String categorySlug) {
            context.push('/buyer/products');
          },
          onProductSelected: (BuyerHomeProduct product) {
            context.push('/buyer/product-details', extra: _toProductDetailFromHome(product));
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
            context.push('/buyer/product-details', extra: _toProductDetail(product));
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
        return OrdersScreen(
          onBack: () => safeBack(context, fallback: '/buyer/home'),
          onShopProducts: () => context.push('/buyer/products'),
        );
      },
    ),

    GoRoute(
      path: '/buyer/messages',
      name: 'buyer-messages',
      builder: (BuildContext context, GoRouterState state) {
        return MessagesScreen(
          onBack: () => safeBack(context, fallback: '/buyer/home'),
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
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
              ),

              const SizedBox(height: 16),

              const Text(
                'Page not found',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                state.uri.toString(),
                textAlign: TextAlign.center,
              ),

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