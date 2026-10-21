import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/login_screen.dart';
import '../models/auth_user_model.dart';
import '../services/auth_service.dart';
import '../services/app_notification_center.dart';
import '../services/buyer_mobile_service.dart';
import '../services/order_service.dart';
import '../services/philippine_address_service.dart';
import '../services/product_service.dart';
import '../services/store_service.dart';
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
import '../features/buyer/store/store_screen.dart';
import '../features/buyer/settings/buyer_system_settings_screen.dart';
import '../features/buyer/wishlist/wishlist_screen.dart';
import '../features/rider/dashboard/dashboard_screen.dart';
import '../features/rider/deliveries/rider_deliveries_screen.dart';
import '../features/rider/deliveries/rider_delivery_details_screen.dart';
import '../features/rider/deliveries/rider_delivery_models.dart';
import '../features/rider/deliveries/rider_delivery_tracking_screen.dart';
import '../features/rider/earnings/rider_earnings_screen.dart';
import '../features/rider/history/rider_history_screen.dart';
import '../features/rider/messages/rider_messages_screen.dart';
import '../features/rider/pickups/rider_pickup_batch_details_screen.dart';
import '../features/rider/pickups/rider_pickup_details_screen.dart';
import '../features/rider/pickups/rider_pickups_screen.dart';
import '../features/rider/profile/rider_profile_screen.dart';
import '../features/rider/profile/rider_profile_edit_screen.dart';
import '../features/rider/rider_availability_tracker.dart';
import '../features/rider/rider_navigation.dart';
import '../features/rider/rider_api_loader.dart';
import '../features/rider/scanner/rider_scanner_screen.dart';
import '../services/rider_mobile_service.dart';
import '../shared/widgets/buyer_navigation.dart';
import '../shared/widgets/async_route_builder.dart';

void safeBack(BuildContext context, {String fallback = '/login'}) {
  if (context.canPop()) {
    context.pop();
    return;
  }

  context.go(fallback);
}

Widget _authTheme(Widget child) {
  return Theme(data: AppTheme.lightTheme, child: child);
}

Future<void> _toggleApiWishlist(int productId) async {
  final bool wishlisted = await BuyerMobileService.toggleWishlist(productId);
  WishlistService.setProductWishlisted(productId, wishlisted);
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
    sellerUserId: product.sellerUserId,
    wishlisted: product.wishlisted,
    sellerOnVacation: product.sellerOnVacation,
    isActive: product.isActive,
    isDraft: product.isDraft,
    isDeleted: product.isDeleted,
  );
}

WishlistProduct _wishlistProductFromHome(BuyerHomeProduct product) {
  return WishlistProduct(
    id: product.id,
    name: product.name,
    slug: product.slug,
    category: product.category,
    sellerName: product.sellerName,
    sellerSlug: product.sellerSlug,
    sellerUserId: product.sellerUserId,
    imageUrl: product.imageUrl,
    price: product.price,
    originalPrice: product.originalPrice,
    rating: product.rating,
    soldCount: product.soldCount,
    stock: product.stock,
    isActive: product.isActive,
    isDraft: product.isDraft,
    isDeleted: product.isDeleted,
    sellerOnVacation: product.sellerOnVacation,
  );
}

WishlistProduct _wishlistProductFromBuyerProduct(BuyerProduct product) {
  return WishlistProduct(
    id: product.id,
    name: product.name,
    slug: product.slug,
    category: product.category,
    sellerName: product.sellerName,
    sellerSlug: product.sellerSlug,
    sellerUserId: product.sellerUserId,
    imageUrl: product.imageUrl,
    price: product.price,
    originalPrice: product.originalPrice,
    rating: product.rating,
    soldCount: product.soldCount,
    stock: product.stock,
    isActive: product.isActive,
    isDraft: product.isDraft,
    isDeleted: product.isDeleted,
    sellerOnVacation: product.sellerOnVacation,
  );
}

WishlistProduct _wishlistProductFromStoreProduct(
  StoreProductData product,
  StoreSellerData seller,
) {
  return WishlistProduct(
    id: product.id,
    name: product.name,
    slug: product.slug,
    category: product.category,
    sellerName: seller.name,
    sellerSlug: seller.slug,
    sellerUserId: seller.id == 0 ? null : seller.id,
    imageUrl: product.imageUrl,
    price: product.price,
    originalPrice: product.originalPrice,
    rating: product.rating,
    soldCount: product.soldCount,
    stock: product.stock,
    isActive: product.isActive,
    isDraft: product.isDraft,
    isDeleted: product.isDeleted,
    sellerOnVacation: seller.onVacation,
  );
}

WishlistProduct _wishlistProductFromProductDetail(ProductDetailData product) {
  return WishlistProduct(
    id: product.id,
    name: product.name,
    slug: product.slug,
    category: product.category,
    sellerName: product.sellerName,
    sellerSlug: product.sellerSlug,
    sellerUserId: product.sellerUserId,
    imageUrl: product.imageUrl,
    price: product.price,
    originalPrice: product.originalPrice,
    rating: product.rating,
    reviewCount: product.reviewCount,
    soldCount: product.soldCount,
    stock: product.stock,
    isActive: product.isActive,
    isDraft: product.isDraft,
    isDeleted: product.isDeleted,
    sellerOnVacation: product.sellerOnVacation,
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
    sellerUserId: product.sellerUserId,
    wishlisted: product.wishlisted,
    sellerOnVacation: product.sellerOnVacation,
    isActive: product.isActive,
    isDraft: product.isDraft,
    isDeleted: product.isDeleted,
  );
}

StoreSellerData _storeSellerFromProduct(ProductDetailData product) {
  return StoreSellerData(
    id: product.sellerUserId ?? 0,
    name: product.sellerName ?? 'Seller',
    slug: product.sellerSlug ?? '',
    avatarUrl: product.sellerAvatarUrl,
    location: product.sellerLocation,
    verified: product.sellerVerified,
    onVacation: product.sellerOnVacation,
  );
}

StoreSellerData _storeSellerFromConversation(BuyerConversationData seller) {
  // The buyer messages endpoint may return a conversation placeholder such as
  // "conversation-123" instead of a real seller store key. Laravel accepts
  // the seller's business name as a store route key, so use it as a safe
  // fallback. This also keeps older/deployed API responses working.
  final String conversationSlug = seller.slug.trim();
  final bool isConversationPlaceholder =
      conversationSlug.isEmpty ||
      conversationSlug.toLowerCase().startsWith('conversation-');
  final String storeRouteKey = isConversationPlaceholder
      ? seller.name.trim()
      : conversationSlug;

  return StoreSellerData(
    id: int.tryParse(seller.sellerId) ?? 0,
    name: seller.name,
    slug: storeRouteKey,
    avatarUrl: seller.avatarUrl,
  );
}

String _storeRouteKey(StoreSellerData seller) {
  final String slug = seller.slug.trim();
  return slug.isNotEmpty ? slug : seller.name.trim();
}

BuyerConversationData _conversationFromStoreSeller(StoreSellerData seller) {
  return BuyerConversationData(
    sellerId: seller.id.toString(),
    name: seller.name,
    slug: seller.slug,
    avatarUrl: seller.avatarUrl,
  );
}

ProductDetailData _toProductDetailFromStore(
  StoreProductData product,
  StoreSellerData seller,
) {
  return ProductDetailData(
    id: product.id,
    name: product.name,
    slug: product.slug,
    category: product.category,
    imageUrl: product.imageUrl,
    price: product.price,
    originalPrice: product.originalPrice,
    stock: product.stock ?? 0,
    rating: product.rating,
    soldCount: product.soldCount,
    sellerName: seller.name,
    sellerSlug: seller.slug,
    sellerUserId: seller.id == 0 ? null : seller.id,
    sellerAvatarUrl: seller.avatarUrl,
    sellerLocation: seller.location,
    sellerVerified: seller.verified == true,
    wishlisted: product.wishlisted,
    sellerOnVacation: seller.onVacation,
    isActive: product.isActive,
    isDraft: product.isDraft,
    isDeleted: product.isDeleted,
  );
}

Widget _productDetailScreen(BuildContext context, ProductDetailData product) {
  return ProductDetailsScreen(
    product: product,
    relatedProducts: const [],
    onBack: () => safeBack(context, fallback: '/buyer/products'),
    onCart: () => context.push('/buyer/cart'),
    onVouchers: () => context.push('/buyer/rewards'),
    onAddToCartRequest: AppConfig.apiEnabled
        ? (ProductPurchaseRequest request) async {
            await BuyerMobileService.addCartItem(
              productId: request.productId,
              productVariantId:
                  request.productVariationId ??
                  (throw const FormatException('Please select a variation.')),
              quantity: request.quantity,
            );
          }
        : null,
    onWishlistToggle: (ProductDetailData detail) async {
      if (AppConfig.apiEnabled) {
        await _toggleApiWishlist(detail.id);
      } else {
        await WishlistService.toggleLocalProduct(
          _wishlistProductFromProductDetail(detail),
        );
      }
    },
    onBuyNowRequest: (ProductPurchaseRequest request) async {
      if (context.mounted) {
        if (AppConfig.apiEnabled) {
          final CartItemData cartItem = await BuyerMobileService.addCartItem(
            productId: request.productId,
            productVariantId:
                request.productVariationId ??
                (throw const FormatException('Please select a variation.')),
            quantity: request.quantity,
          );
          if (!context.mounted) return;
          context.push(
            '/buyer/checkout',
            extra: _BuyerCheckoutRouteData(
              items: <CheckoutItemData>[_checkoutItemFromCart(cartItem)],
              cartItemIds: <int>[int.parse(cartItem.id)],
            ),
          );
        } else {
          context.push(
            '/buyer/checkout',
            extra: <CheckoutItemData>[_toCheckoutItem(product, request)],
          );
        }
      }
    },
    onViewStore: (ProductDetailData detail) {
      context.push('/buyer/store', extra: _storeSellerFromProduct(detail));
    },
    onMessageSeller: product.sellerUserId == null
        ? null
        : (ProductDetailData detail) {
            context.push(
              '/buyer/messages',
              extra: BuyerConversationData(
                sellerId: detail.sellerUserId.toString(),
                name: detail.sellerName ?? 'Seller',
                slug: detail.sellerSlug ?? detail.sellerName ?? '',
              ),
            );
          },
  );
}

void _goBuyerTab(BuildContext context, int index) {
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell != null) {
    shell.goBranch(index);
  } else {
    const paths = [
      '/buyer/home',
      '/buyer/orders',
      '/buyer/messages',
      '/buyer/profile',
    ];
    context.go(paths[index]);
  }
}

String? _notificationOrderReference(BuyerNotificationData notification) {
  final RegExpMatch? textReference = RegExp(
    r'\b(?:LK|TRK|SO)-[A-Z0-9]+(?:-[A-Z0-9]+)*\b',
    caseSensitive: false,
  ).firstMatch('${notification.title} ${notification.message}');
  if (textReference != null) return textReference.group(0);

  final String relatedOrderId = notification.relatedOrderId?.trim() ?? '';
  if (relatedOrderId.isNotEmpty) return relatedOrderId;

  final String actionUrl = notification.actionUrl?.trim() ?? '';
  if (actionUrl.isEmpty) return null;

  final Uri? uri = Uri.tryParse(actionUrl);
  if (uri == null) return null;

  for (final String key in <String>[
    'order_id',
    'orderId',
    'order',
    'order_number',
    'seller_order_number',
    'sellerOrderNumber',
    'seller_order_id',
    'seller_order',
    'shipment_id',
    'shipmentId',
    'shipment',
    'parcel_id',
    'parcelId',
    'tracking',
    'tracking_number',
    'id',
  ]) {
    final String value = uri.queryParameters[key]?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }

  final List<String> segments = uri.pathSegments;
  const Set<String> referencePaths = <String>{
    'order',
    'orders',
    'order-detail',
    'order-details',
    'order_detail',
    'shipment',
    'shipments',
    'parcel',
    'parcels',
  };
  for (int index = 0; index < segments.length - 1; index++) {
    if (referencePaths.contains(segments[index].toLowerCase())) {
      final String reference = segments[index + 1].trim();
      if (reference.isNotEmpty) return reference;
    }
  }

  return null;
}

BuyerOrderData? _findBuyerOrderByReference(
  Iterable<BuyerOrderData> orders,
  String? reference,
) {
  final String normalizedReference = reference?.trim().toLowerCase() ?? '';
  if (normalizedReference.isEmpty) return null;

  for (final BuyerOrderData order in orders) {
    final Set<String> references =
        <String>{
              order.id,
              order.orderNumber ?? '',
              order.sellerOrderNumber ?? '',
              order.tracking ?? '',
              order.shipmentId ?? '',
            }
            .map((String value) => value.trim().toLowerCase())
            .where((String value) => value.isNotEmpty)
            .toSet();
    if (references.contains(normalizedReference)) return order;
  }
  return null;
}

Widget _buyerNavigationFrame(
  BuildContext context, {
  required int currentIndex,
  required Widget child,
  String? aiPage,
  String? aiPageTitle,
}) {
  final String resolvedAiPage =
      aiPage ??
      switch (currentIndex) {
        1 => 'orders',
        2 => 'messages',
        3 => 'account',
        _ => 'buyer',
      };
  final String resolvedAiPageTitle =
      aiPageTitle ??
      switch (currentIndex) {
        1 => 'My Orders',
        2 => 'Messages',
        3 => 'Account',
        _ => 'Buyer portal',
      };

  return BuyerNavigationFrame(
    currentIndex: currentIndex,
    aiPage: resolvedAiPage,
    aiPageTitle: resolvedAiPageTitle,
    onHome: () => _goBuyerTab(context, 0),
    onOrders: () => _goBuyerTab(context, 1),
    onMessages: () => _goBuyerTab(context, 2),
    onProfile: () => _goBuyerTab(context, 3),
    child: child,
  );
}

Widget _riderNavigationFrame(
  BuildContext context, {
  required int currentIndex,
  required Widget child,
}) {
  return _riderScreenPresentation(
    context,
    child: RiderAvailabilityTracker(
      child: RiderNavigationFrame(
        currentIndex: currentIndex,
        onDashboard: () => context.go('/rider/dashboard'),
        onAssignments: () => context.go('/rider/pickups'),
        onHistory: () => context.go('/rider/history'),
        onEarnings: () => context.go('/rider/earnings'),
        onProfile: () => context.go('/rider/profile'),
        child: child,
      ),
    ),
  );
}

Widget _riderScreenPresentation(BuildContext context, {required Widget child}) {
  final MediaQueryData mediaQuery = MediaQuery.of(context);
  final double systemTextScale = mediaQuery.textScaler.scale(16) / 16;
  final double riderTextScale = systemTextScale < 1.05 ? 1.05 : systemTextScale;
  final Duration duration = mediaQuery.disableAnimations
      ? Duration.zero
      : const Duration(milliseconds: 220);

  return MediaQuery(
    data: mediaQuery.copyWith(textScaler: TextScaler.linear(riderTextScale)),
    child: TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: child,
          ),
        );
      },
    ),
  );
}

CheckoutItemData _toCheckoutItem(
  ProductDetailData product,
  ProductPurchaseRequest request,
) {
  ProductVariationData? selectedVariation;
  for (final ProductVariationData variation in product.variations) {
    if (variation.id == request.productVariationId) {
      selectedVariation = variation;
      break;
    }
  }
  return CheckoutItemData(
    id: product.id,
    productId: request.productId,
    sellerId: 0,
    seller: product.sellerName ?? 'LIKHAE Seller',
    name: product.name,
    category: product.category ?? '',
    variant: request.variant ?? '',
    productVariantId: request.productVariationId,
    imageUrl: product.imageUrl,
    price: selectedVariation?.price ?? product.price,
    quantity: request.quantity,
  );
}

CheckoutItemData _checkoutItemFromCart(CartItemData item) {
  return CheckoutItemData(
    id: item.productId ?? 0,
    productId: item.productId ?? 0,
    productVariantId: item.productVariationId,
    sellerId: item.sellerId ?? 0,
    seller: item.seller,
    name: item.name,
    category: item.category,
    variant: item.variant,
    price: item.price,
    quantity: item.quantity,
    imageUrl: item.imageUrl,
  );
}

DeliveryAddressData? _deliveryAddressFromBuyerAddresses(
  List<BuyerAddressData> addresses,
) {
  BuyerAddressData? selected;
  for (final BuyerAddressData address in addresses) {
    if (address.isDefault) {
      selected = address;
      break;
    }
  }

  selected ??= addresses.isEmpty ? null : addresses.first;
  if (selected == null) return null;

  return DeliveryAddressData(
    recipientName: selected.recipientName,
    contactNumber: selected.contactNumber,
    formattedAddress: selected.displayAddress,
    isDefault: selected.isDefault,
  );
}

class _BuyerCheckoutRouteData {
  final List<CheckoutItemData> items;
  final List<int> cartItemIds;
  final Map<int, String> voucherCodes;

  const _BuyerCheckoutRouteData({
    required this.items,
    required this.cartItemIds,
    this.voucherCodes = const <int, String>{},
  });
}

Future<SelectedProfilePhoto?> _pickBuyerProfilePhoto() async {
  final XFile? image = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1200,
    maxHeight: 1200,
    imageQuality: 85,
  );
  if (image == null) {
    return null;
  }
  return SelectedProfilePhoto(
    fileName: image.name,
    bytes: await image.readAsBytes(),
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
    _routeAuthenticatedMobileUser(context, payload);
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

void _routeAuthenticatedMobileUser(
  BuildContext context,
  Map<String, dynamic> payload,
) {
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
  if (!context.mounted) return;

  if (mobileRoles.contains('rider') && !mobileRoles.contains('buyer')) {
    context.go('/rider/dashboard');
    return;
  }

  context.go('/buyer/home');
}

Future<RegistrationDocument?> _pickRegistrationDocument(
  RegistrationDocumentType type,
) async {
  final List<PlatformFile> files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: <String>['jpg', 'jpeg', 'png', 'pdf'],
  );
  if (files.isEmpty) return null;
  final PlatformFile file = files.first;
  if (file.path == null || file.path!.isEmpty) return null;
  return RegistrationDocument(name: file.name, path: file.path);
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',

  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => navigationShell,
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/buyer/home',
              name: 'buyer-home',
              builder: (BuildContext context, GoRouterState state) {
                return BuyerHomeScreen(
                  onSearch: () => context.push('/buyer/products?search=1'),
                  onBrowseProducts: () => context.push('/buyer/products'),
                  onViewOrders: () => _goBuyerTab(context, 1),
                  onWishlist: () => context.push('/buyer/wishlist'),
                  onCart: () => context.push('/buyer/cart'),
                  onNotifications: () => context.push('/buyer/notifications'),
                  onMessages: () => _goBuyerTab(context, 2),
                  onProfile: () => _goBuyerTab(context, 3),
                  onVouchers: () => context.push('/buyer/rewards'),
                  onViewAllCategories: () => context.push('/buyer/products'),
                  onCategorySelected: (String categorySlug) {
                    context.push(
                      '/buyer/products?category=${Uri.encodeComponent(categorySlug)}',
                    );
                  },
                  onShopDeals: () => context.push('/buyer/products?deals=true'),
                  onViewFeatured: () => context.push('/buyer/products'),
                  onViewRecommended: () => context.push('/buyer/products'),
                  onProductSelected: (BuyerHomeProduct product) {
                    context.push(
                      '/buyer/product-details',
                      extra: _toProductDetailFromHome(product),
                    );
                  },
                  onWishlistProductAsync: (BuyerHomeProduct product) async {
                    if (AppConfig.apiEnabled) {
                      await _toggleApiWishlist(product.id);
                    } else {
                      await WishlistService.toggleLocalProduct(
                        _wishlistProductFromHome(product),
                      );
                    }
                  },
                );
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/buyer/orders',
              name: 'buyer-orders',
              builder: (BuildContext context, GoRouterState state) {
                final String? orderReference =
                    state.uri.queryParameters['orderId'] ??
                    state.uri.queryParameters['order_id'];
                final bool openOrderDetails =
                    orderReference?.trim().isNotEmpty == true;
                Future<List<BuyerOrderData>> loadOrders() async {
                  late final List<BuyerOrderData> orders;
                  try {
                    orders = await OrderService.fetchMyOrders();
                  } catch (_) {
                    if (!openOrderDetails) rethrow;
                    orders = <BuyerOrderData>[];
                  }
                  if (!openOrderDetails ||
                      _findBuyerOrderByReference(orders, orderReference) !=
                          null) {
                    return orders;
                  }
                  try {
                    final BuyerOrderData requestedOrder =
                        await BuyerMobileService.fetchOrder(
                          orderReference!.trim(),
                        );
                    return <BuyerOrderData>[...orders, requestedOrder];
                  } catch (_) {
                    return orders;
                  }
                }

                return _buyerNavigationFrame(
                  context,
                  currentIndex: 1,
                  child: AsyncRouteBuilder<List<BuyerOrderData>>(
                    load: loadOrders,
                    refreshOnActivate: true,
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<List<BuyerOrderData>> snapshot,
                        ) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const RouteLoadingPage(title: 'Orders');
                          }

                          final List<BuyerOrderData> orders =
                              snapshot.data ?? const <BuyerOrderData>[];
                          final BuyerOrderData? requestedOrder =
                              _findBuyerOrderByReference(
                                orders,
                                orderReference,
                              );
                          return OrdersScreen(
                            orders: orders,
                            showProductPreviewWhenEmpty: !AppConfig.apiEnabled,
                            initialMode: openOrderDetails
                                ? BuyerOrdersMode.details
                                : BuyerOrdersMode.overview,
                            selectedOrderId:
                                requestedOrder?.id ?? orderReference,
                            buyerNotice: snapshot.hasError
                                ? 'Orders could not be loaded. Pull down to try again.'
                                : null,
                            onBack: () =>
                                safeBack(context, fallback: '/buyer/home'),
                            onShopProducts: () =>
                                context.push('/buyer/products'),
                            onRefresh: AppConfig.apiEnabled
                                ? BuyerMobileService.fetchOrders
                                : null,
                            onCancelOrder: AppConfig.apiEnabled
                                ? (
                                    BuyerOrderData order,
                                    String reason,
                                    String note,
                                  ) => BuyerMobileService.cancelOrder(
                                    order,
                                    reason,
                                    note,
                                  )
                                : null,
                            onReceiveOrder: AppConfig.apiEnabled
                                ? BuyerMobileService.confirmOrderReceived
                                : null,
                            onSubmitProductReview: AppConfig.apiEnabled
                                ? BuyerMobileService.submitProductReview
                                : null,
                            onSubmitReturnRequest: AppConfig.apiEnabled
                                ? BuyerMobileService.requestOrderReturn
                                : null,
                            onTrackOrder: (BuyerOrderData order) {
                              context.push(
                                '/buyer/order-tracking',
                                extra: order,
                              );
                            },
                            onContactSeller: (BuyerOrderData order) {
                              final String sellerName =
                                  order.sellerName?.trim().isNotEmpty == true
                                  ? order.sellerName!.trim()
                                  : 'Seller';
                              context.push(
                                '/buyer/messages',
                                extra: BuyerConversationData(
                                  sellerId: order.sellerId!.toString(),
                                  name: sellerName,
                                  slug:
                                      order.sellerSlug?.trim().isNotEmpty ==
                                          true
                                      ? order.sellerSlug!.trim()
                                      : sellerName,
                                  avatarUrl: order.sellerAvatarUrl,
                                ),
                              );
                            },
                            onViewStore: (BuyerOrderData order) {
                              final String sellerName =
                                  order.sellerName?.trim().isNotEmpty == true
                                  ? order.sellerName!.trim()
                                  : 'Seller';
                              context.push(
                                '/buyer/store',
                                extra: StoreSellerData(
                                  id: order.sellerId ?? 0,
                                  name: sellerName,
                                  slug:
                                      order.sellerSlug?.trim().isNotEmpty ==
                                          true
                                      ? order.sellerSlug!.trim()
                                      : sellerName,
                                  avatarUrl: order.sellerAvatarUrl,
                                ),
                              );
                            },
                          );
                        },
                  ),
                );
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/buyer/messages',
              name: 'buyer-messages',
              builder: (BuildContext context, GoRouterState state) {
                Widget buildMessages(
                  List<BuyerConversationData> conversations,
                ) {
                  return _buyerNavigationFrame(
                    context,
                    currentIndex: 2,
                    child: MessagesScreen(
                      conversations: conversations,
                      initialSeller: state.extra is BuyerConversationData
                          ? state.extra! as BuyerConversationData
                          : null,
                      showPreviewWhenEmpty: !AppConfig.apiEnabled,
                      onBack: () => safeBack(context, fallback: '/buyer/home'),
                      onRefreshConversations: AppConfig.apiEnabled
                          ? BuyerMobileService.fetchConversations
                          : null,
                      onLoadMessages: AppConfig.apiEnabled
                          ? BuyerMobileService.fetchMessages
                          : null,
                      onSendMessage: AppConfig.apiEnabled
                          ? BuyerMobileService.sendMessage
                          : null,
                      onSendAttachment: AppConfig.apiEnabled
                          ? BuyerMobileService.sendAttachment
                          : null,
                      onViewStore: (BuyerConversationData seller) {
                        context.push(
                          '/buyer/store',
                          extra: _storeSellerFromConversation(seller),
                        );
                      },
                      messageStreamBuilder: AppConfig.apiEnabled
                          ? BuyerMobileService.watchMessages
                          : null,
                    ),
                  );
                }

                if (!AppConfig.apiEnabled) {
                  return buildMessages(const <BuyerConversationData>[]);
                }
                return AsyncRouteBuilder<List<BuyerConversationData>>(
                  load: () => BuyerMobileService.fetchConversations(),
                  refreshOnActivate: true,
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<BuyerConversationData>> snapshot,
                      ) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return _buyerNavigationFrame(
                            context,
                            currentIndex: 2,
                            child: const RouteLoadingPage(title: 'Messages'),
                          );
                        }
                        if (snapshot.hasError) {
                          return Scaffold(
                            appBar: AppBar(
                              title: const Text('Messages'),
                              leading: IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () =>
                                    safeBack(context, fallback: '/buyer/home'),
                              ),
                            ),
                            body: Center(
                              child: Text(
                                'Unable to load messages: ${snapshot.error}',
                              ),
                            ),
                          );
                        }
                        return buildMessages(
                          snapshot.data ?? const <BuyerConversationData>[],
                        );
                      },
                );
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/buyer/profile',
              name: 'buyer-profile',
              builder: (BuildContext context, GoRouterState state) {
                final bool separatePage = state.extra is BuyerAccountTab;
                final BuyerAccountTab initialTab =
                    state.extra is BuyerAccountTab
                    ? state.extra! as BuyerAccountTab
                    : BuyerAccountTab.profile;
                Future<List<Object>> loadBuyerAccount() async {
                  if (AppConfig.apiEnabled) {
                    final List<dynamic> results =
                        await Future.wait<dynamic>(<Future<dynamic>>[
                          BuyerMobileService.fetchProfile(),
                          BuyerMobileService.fetchBuyerAddresses(),
                        ]);
                    return <Object>[
                      results[0] as BuyerProfileData,
                      results[1] as List<BuyerAddressData>,
                    ];
                  }
                  final AuthUserModel user = await AuthService.getCurrentUser();
                  return <Object>[
                    BuyerProfileData(
                      name: user.name,
                      email: user.email ?? '',
                      phone: user.contactNumber ?? '',
                    ),
                    const <BuyerAddressData>[],
                  ];
                }

                return _buyerNavigationFrame(
                  context,
                  currentIndex: 3,
                  child: AsyncRouteBuilder<List<Object>>(
                    load: () => loadBuyerAccount(),
                    refreshOnActivate: true,
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<List<Object>> snapshot,
                        ) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const RouteLoadingPage(title: 'Account');
                          }

                          if (snapshot.hasError || !snapshot.hasData) {
                            return Scaffold(
                              appBar: AppBar(
                                title: const Text('Profile'),
                                leading: IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => safeBack(
                                    context,
                                    fallback: '/buyer/home',
                                  ),
                                ),
                              ),
                              body: Center(
                                child: Text(
                                  'Unable to load your profile: ${snapshot.error ?? 'No profile data was returned.'}',
                                ),
                              ),
                            );
                          }

                          final BuyerProfileData profile =
                              snapshot.data![0] as BuyerProfileData;
                          final List<BuyerAddressData> addresses =
                              snapshot.data![1] as List<BuyerAddressData>;

                          return AccountScreen(
                            profile: profile,
                            addresses: addresses,
                            initialTab: initialTab,
                            showNavigationTabs: !separatePage,
                            onBack: () =>
                                safeBack(context, fallback: '/buyer/home'),
                            onPickProfilePhoto: _pickBuyerProfilePhoto,
                            onUpdateProfile: AppConfig.apiEnabled
                                ? BuyerMobileService.updateProfile
                                : null,
                            onRemoveProfilePhoto: AppConfig.apiEnabled
                                ? BuyerMobileService.deleteProfilePhoto
                                : null,
                            onAddAddress: AppConfig.apiEnabled
                                ? BuyerMobileService.createBuyerAddress
                                : null,
                            loadRegions: PhilippineAddressService.fetchRegions,
                            loadProvinces:
                                PhilippineAddressService.fetchProvinces,
                            loadMunicipalities:
                                PhilippineAddressService.fetchMunicipalities,
                            loadBarangays:
                                PhilippineAddressService.fetchBarangays,
                            loadPostalCode:
                                PhilippineAddressService.fetchPostalCode,
                            onDeleteAddress: AppConfig.apiEnabled
                                ? BuyerMobileService.deleteBuyerAddress
                                : null,
                            onSetDefaultAddress: AppConfig.apiEnabled
                                ? BuyerMobileService.setDefaultBuyerAddress
                                : null,
                            onChangePassword: AppConfig.apiEnabled
                                ? BuyerMobileService.changePassword
                                : null,
                            onSystemSettings: () =>
                                context.push('/buyer/settings'),
                            onVouchers: () => context.push('/buyer/rewards'),
                            onTabChanged: (BuyerAccountTab tab) {
                              if (tab == BuyerAccountTab.vouchers) {
                                context.push('/buyer/rewards');
                                return;
                              }
                              if (tab == BuyerAccountTab.settings) {
                                context.push('/buyer/settings');
                                return;
                              }
                              context.push('/buyer/profile', extra: tab);
                            },
                            onRefresh: AppConfig.apiEnabled
                                ? BuyerMobileService.fetchAccountSnapshot
                                : null,
                            onLogout: () async {
                              await AuthService.logout();
                              if (context.mounted) {
                                context.go('/login');
                              }
                            },
                          );
                        },
                  ),
                );
              },
            ),

            // ── Rider ─────────────────────────────────────────────────────────────────
          ],
        ),
      ],
    ),
    // ── Auth ─────────────────────────────────────────────────────────────────
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (BuildContext context, GoRouterState state) {
        return _authTheme(
          LoginScreen(
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
            onGoogleSignIn: () async {
              try {
                final Map<String, dynamic> payload =
                    await AuthService.signInWithGoogle();
                _routeAuthenticatedMobileUser(context, payload);
              } on GoogleRegistrationRequiredException catch (error) {
                if (context.mounted) {
                  context.push('/register', extra: error.profile);
                }
              }
            },
          ),
        );
      },
    ),

    GoRoute(
      path: '/register',
      name: 'register',
      builder: (BuildContext context, GoRouterState state) {
        final Map<String, dynamic>? googleProfile = state.extra is Map
            ? Map<String, dynamic>.from(state.extra as Map)
            : null;
        return _authTheme(
          RegisterScreen(
            googleProfile: googleProfile,
            onSendEmailVerificationCode:
                AuthService.sendRegistrationEmailVerificationCode,
            onVerifyEmailVerificationCode:
                AuthService.verifyRegistrationEmailVerificationCode,
            onSubmit: (RegisterFormData data) async {
              final Map<String, dynamic> payload = await AuthService.register(
                data,
              );
              if (!context.mounted) return;
              final dynamic message = payload['message'];
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    message?.toString() ?? 'Registration submitted.',
                  ),
                ),
              );
              context.go('/login');
            },
            onPickDocument: _pickRegistrationDocument,
            loadRegions: PhilippineAddressService.fetchRegions,
            loadProvinces: PhilippineAddressService.fetchProvinces,
            loadMunicipalities: PhilippineAddressService.fetchMunicipalities,
            loadBarangays: PhilippineAddressService.fetchBarangays,
            loadPostalCode: PhilippineAddressService.fetchPostalCode,
          ),
        );
      },
    ),

    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (BuildContext context, GoRouterState state) {
        return _authTheme(const ForgotPasswordScreen());
      },
    ),

    // ── Buyer ─────────────────────────────────────────────────────────────────
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

        if (!AppConfig.apiEnabled || product.slug?.trim().isNotEmpty != true) {
          return _productDetailScreen(context, product);
        }

        return AsyncRouteBuilder<ProductDetailData>(
          load: () => ProductService.fetchProductDetails(product.slug!),
          requestKey: product.slug,
          refreshOnActivate: true,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<ProductDetailData> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const RouteLoadingPage(title: 'Product details');
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Scaffold(
                    appBar: AppBar(
                      leading: IconButton(
                        onPressed: () =>
                            safeBack(context, fallback: '/buyer/products'),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      title: const Text('Product details'),
                    ),
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Unable to load product details: '
                          '${snapshot.error ?? 'No product data was returned.'}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }
                return _productDetailScreen(context, snapshot.data!);
              },
        );
      },
    ),

    GoRoute(
      path: '/buyer/products',
      name: 'buyer-products',
      builder: (BuildContext context, GoRouterState state) {
        return ProductsScreen(
          initialCategorySlug: state.uri.queryParameters['category'],
          dealsOnly: state.uri.queryParameters['deals'] == 'true',
          searchOnOpen: state.uri.queryParameters['search'] == '1',
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
            if (AppConfig.apiEnabled) {
              await _toggleApiWishlist(product.id);
            } else {
              await WishlistService.toggleLocalProduct(
                _wishlistProductFromBuyerProduct(product),
              );
            }
          },
        );
      },
    ),

    GoRoute(
      path: '/buyer/store',
      name: 'buyer-store',
      builder: (BuildContext context, GoRouterState state) {
        final dynamic extra = state.extra;
        final StoreSellerData? requestedSeller = extra is StoreSellerData
            ? extra
            : extra is BuyerConversationData
            ? _storeSellerFromConversation(extra)
            : null;

        if (requestedSeller == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => safeBack(context, fallback: '/buyer/home'),
                icon: const Icon(Icons.arrow_back),
              ),
              title: const Text('Store'),
            ),
            body: const Center(child: Text('This store is unavailable.')),
          );
        }

        final String storeRouteKey = _storeRouteKey(requestedSeller);

        if (AppConfig.apiEnabled && storeRouteKey.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => safeBack(context, fallback: '/buyer/home'),
                icon: const Icon(Icons.arrow_back),
              ),
              title: const Text('Store'),
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This seller does not have a store page yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        Future<StorePageData> loadStore() => AppConfig.apiEnabled
            ? StoreService.fetchStore(storeRouteKey)
            : Future<StorePageData>.value(
                StorePageData(
                  seller: requestedSeller,
                  products: const <StoreProductData>[],
                ),
              );

        return AsyncRouteBuilder<StorePageData>(
          load: loadStore,
          requestKey: storeRouteKey,
          refreshOnActivate: true,
          builder: (BuildContext context, AsyncSnapshot<StorePageData> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const RouteLoadingPage(title: 'Store');
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    onPressed: () => safeBack(context, fallback: '/buyer/home'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  title: const Text('Store'),
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Unable to load this store: ${snapshot.error ?? 'No store data was returned.'}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            final StorePageData store = snapshot.data!;
            return StoreScreen(
              seller: store.seller,
              products: store.products,
              onBack: () => safeBack(context, fallback: '/buyer/home'),
              onMessageSeller: store.seller.id == 0
                  ? null
                  : () {
                      context.push(
                        '/buyer/messages',
                        extra: _conversationFromStoreSeller(store.seller),
                      );
                    },
              onFollowShop: (bool following) =>
                  StoreService.setStoreFollowing(storeRouteKey, following),
              onProductSelected: (StoreProductData product) {
                context.push(
                  '/buyer/product-details',
                  extra: _toProductDetailFromStore(product, store.seller),
                );
              },
              onWishlistProduct: (StoreProductData product) async {
                if (AppConfig.apiEnabled) {
                  await _toggleApiWishlist(product.id);
                } else {
                  await WishlistService.toggleLocalProduct(
                    _wishlistProductFromStoreProduct(product, store.seller),
                  );
                }
              },
            );
          },
        );
      },
    ),

    GoRoute(
      path: '/buyer/wishlist',
      name: 'buyer-wishlist',
      builder: (BuildContext context, GoRouterState state) {
        WishlistScreen buildWishlist(List<WishlistProduct> products) {
          final Map<int, WishlistProduct> unique = <int, WishlistProduct>{};
          for (final WishlistProduct product in products) {
            if (product.id > 0) unique[product.id] = product;
          }
          final List<WishlistProduct> visible = unique.values.toList(
            growable: false,
          );
          WishlistService.replaceWithWishlist(
            visible.map((WishlistProduct product) => product.id),
          );
          return WishlistScreen(
            products: visible,
            onBack: () => safeBack(context, fallback: '/buyer/home'),
            onContinueShopping: () => context.push('/buyer/home'),
            onCart: () => context.push('/buyer/cart'),
            onNotifications: () => context.push('/buyer/notifications'),
            onRefresh: AppConfig.apiEnabled
                ? () async {
                    final List<WishlistProduct> refreshed =
                        await BuyerMobileService.fetchWishlist();
                    WishlistService.replaceWithWishlist(
                      refreshed.map((WishlistProduct product) => product.id),
                    );
                    return refreshed;
                  }
                : WishlistService.fetchLocalWishlist,
            onRemoveProduct: AppConfig.apiEnabled
                ? (WishlistProduct product) async {
                    await BuyerMobileService.toggleWishlist(product.id);
                    WishlistService.setProductWishlisted(product.id, false);
                  }
                : (WishlistProduct product) =>
                      WishlistService.removeLocalProduct(product.id),
            onClearWishlist: AppConfig.apiEnabled
                ? () async {
                    final List<WishlistProduct> current =
                        await BuyerMobileService.fetchWishlist();
                    for (final WishlistProduct product in current) {
                      await BuyerMobileService.toggleWishlist(product.id);
                      WishlistService.setProductWishlisted(product.id, false);
                    }
                  }
                : WishlistService.clearLocalWishlist,
            onProductSelected: (WishlistProduct product) {
              context.push(
                '/buyer/product-details',
                extra: ProductDetailData(
                  id: product.id,
                  name: product.name,
                  slug: product.slug,
                  category: product.category,
                  sellerName: product.sellerName,
                  imageUrl: product.imageUrl,
                  price: product.price,
                  originalPrice: product.originalPrice,
                  rating: product.rating,
                  reviewCount: product.reviewCount,
                  soldCount: product.soldCount,
                  stock: product.stock ?? 0,
                  sellerUserId: product.sellerUserId,
                  wishlisted: WishlistService.isWishlisted(product.id),
                  sellerOnVacation: product.sellerOnVacation,
                  isActive: product.isActive,
                  isDraft: product.isDraft,
                  isDeleted: product.isDeleted,
                ),
              );
            },
          );
        }

        if (!AppConfig.apiEnabled) {
          return buildWishlist(WishlistService.localWishlist);
        }
        return AsyncRouteBuilder<List<WishlistProduct>>(
          load: () => BuyerMobileService.fetchWishlist(),
          refreshOnActivate: true,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<WishlistProduct>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const RouteLoadingPage(title: 'Wishlist');
                }
                if (snapshot.hasError) {
                  return Scaffold(
                    appBar: AppBar(
                      title: const Text('Wishlist'),
                      leading: IconButton(
                        onPressed: () =>
                            safeBack(context, fallback: '/buyer/home'),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                    body: Center(
                      child: Text(
                        'Unable to load your wishlist: ${snapshot.error}',
                      ),
                    ),
                  );
                }
                return buildWishlist(
                  snapshot.data ?? const <WishlistProduct>[],
                );
              },
        );
      },
    ),

    GoRoute(
      path: '/buyer/notifications',
      name: 'buyer-notifications',
      builder: (BuildContext context, GoRouterState state) {
        NotificationsScreen buildNotifications(
          List<BuyerNotificationData> notifications,
        ) {
          return NotificationsScreen(
            notifications: notifications,
            onBack: () => safeBack(context, fallback: '/buyer/home'),
            onRefresh: AppConfig.apiEnabled
                ? BuyerMobileService.fetchNotifications
                : null,
            realtimeStreamBuilder: AppConfig.realtimeEnabled
                ? BuyerMobileService.watchNotifications
                : null,
            onMarkAllAsRead: AppConfig.apiEnabled
                ? BuyerMobileService.markAllNotificationsRead
                : null,
            onNotificationTap: (notification) async {
              final String? orderReference = _notificationOrderReference(
                notification,
              );
              switch (notification.type) {
                case BuyerNotificationType.orders:
                case BuyerNotificationType.deliveries:
                  final Uri ordersUri = Uri(
                    path: '/buyer/orders',
                    queryParameters: orderReference == null
                        ? null
                        : <String, String>{'orderId': orderReference},
                  );
                  final ModalRoute<dynamic>? notificationRoute =
                      ModalRoute.of<dynamic>(context);
                  if (context.mounted && context.canPop()) {
                    context.pop();
                    if (notificationRoute != null) {
                      await notificationRoute.completed;
                    }
                  }
                  await WidgetsBinding.instance.endOfFrame;
                  appRouter.go(ordersUri.toString());
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
        }

        if (!AppConfig.apiEnabled) {
          return buildNotifications(const <BuyerNotificationData>[]);
        }
        return AsyncRouteBuilder<List<BuyerNotificationData>>(
          load: () => BuyerMobileService.fetchNotifications(),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<BuyerNotificationData>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const RouteLoadingPage(title: 'Notifications');
                }
                if (snapshot.hasError) {
                  return Scaffold(
                    appBar: AppBar(
                      title: const Text('Notifications'),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () =>
                            safeBack(context, fallback: '/buyer/home'),
                      ),
                    ),
                    body: Center(
                      child: Text(
                        'Unable to load notifications: ${snapshot.error}',
                      ),
                    ),
                  );
                }
                return buildNotifications(
                  snapshot.data ?? const <BuyerNotificationData>[],
                );
              },
        );
      },
    ),

    GoRoute(
      path: '/buyer/cart',
      name: 'buyer-cart',
      builder: (BuildContext context, GoRouterState state) {
        final Map<int, String> voucherCodes = state.extra is Map<int, String>
            ? Map<int, String>.from(state.extra! as Map<int, String>)
            : const <int, String>{};
        Widget buildCart(
          List<CartItemData> items,
          DeliveryAddressData? defaultAddress,
        ) => CartScreen(
          items: items,
          defaultAddress: defaultAddress,
          initialVoucherCodes: voucherCodes,
          loadAvailableVouchers: AppConfig.apiEnabled
              ? () async =>
                    (await BuyerMobileService.fetchRewards()).activeVouchers
              : null,
          onBack: () => safeBack(context, fallback: '/buyer/home'),
          onSellerSelected: (String sellerName, int? sellerId) {
            final String storeRouteKey =
                sellerId?.toString() ?? sellerName.trim();
            if (storeRouteKey.isEmpty) return;
            context.push(
              '/buyer/store',
              extra: StoreSellerData(
                id: sellerId ?? 0,
                name: sellerName,
                slug: storeRouteKey,
              ),
            );
          },
          onContinueShopping: () => context.push('/buyer/home'),
          onChangeAddress: () =>
              context.push('/buyer/profile', extra: BuyerAccountTab.addresses),
          onRefresh: AppConfig.apiEnabled ? BuyerMobileService.fetchCart : null,
          onUpdateQuantity: AppConfig.apiEnabled
              ? BuyerMobileService.updateCartQuantity
              : null,
          onRemoveItem: AppConfig.apiEnabled
              ? BuyerMobileService.removeCartItem
              : null,
          onRemoveSelected: AppConfig.apiEnabled
              ? (List<CartItemData> selected) async {
                  for (final CartItemData item in selected) {
                    await BuyerMobileService.removeCartItem(item);
                  }
                }
              : null,
          onCheckout: AppConfig.apiEnabled
              ? (CartCheckoutRequest request) async {
                  final Map<String, int> selectedQuantities = <String, int>{
                    for (final CartCheckoutItem item in request.items)
                      item.id: item.quantity,
                  };
                  final List<CartItemData> selectedItems = items
                      .where(
                        (CartItemData item) =>
                            selectedQuantities.containsKey(item.id),
                      )
                      .map(
                        (CartItemData item) => item.copyWith(
                          quantity: selectedQuantities[item.id],
                        ),
                      )
                      .toList(growable: false);
                  final List<int> cartItemIds = selectedItems
                      .map((CartItemData item) => int.tryParse(item.id))
                      .whereType<int>()
                      .toList(growable: false);
                  if (selectedItems.isEmpty ||
                      cartItemIds.length != selectedItems.length) {
                    throw const FormatException(
                      'The selected cart items could not be identified.',
                    );
                  }
                  await context.push<void>(
                    '/buyer/checkout',
                    extra: _BuyerCheckoutRouteData(
                      items: selectedItems
                          .map(_checkoutItemFromCart)
                          .toList(growable: false),
                      cartItemIds: cartItemIds,
                      voucherCodes: request.voucherCodes,
                    ),
                  );
                }
              : null,
        );

        Future<List<Object>> loadCartData() async {
          return Future.wait<Object>([
            BuyerMobileService.fetchCart(),
            BuyerMobileService.fetchBuyerAddresses().catchError(
              (Object _) => <BuyerAddressData>[],
            ),
          ]);
        }

        if (!AppConfig.apiEnabled) {
          return buildCart(const <CartItemData>[], null);
        }
        return AsyncRouteBuilder<List<Object>>(
          load: () => loadCartData(),
          refreshOnActivate: true,
          builder: (BuildContext context, AsyncSnapshot<List<Object>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const RouteLoadingPage(title: 'Cart');
            }
            if (snapshot.hasError) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Cart'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => safeBack(context, fallback: '/buyer/home'),
                  ),
                ),
                body: Center(
                  child: Text(
                    'Unable to load your cart or delivery address: ${snapshot.error}',
                  ),
                ),
              );
            }
            final List<Object> data = snapshot.data ?? const <Object>[];
            final List<CartItemData> items = data.isNotEmpty
                ? data[0] as List<CartItemData>
                : const <CartItemData>[];
            final List<BuyerAddressData> addresses = data.length > 1
                ? data[1] as List<BuyerAddressData>
                : const <BuyerAddressData>[];
            return buildCart(
              items,
              _deliveryAddressFromBuyerAddresses(addresses),
            );
          },
        );
      },
    ),

    GoRoute(
      path: '/buyer/checkout',
      name: 'buyer-checkout',
      builder: (BuildContext context, GoRouterState state) {
        final dynamic extra = state.extra;
        final _BuyerCheckoutRouteData? routeData =
            extra is _BuyerCheckoutRouteData ? extra : null;
        final List<CheckoutItemData> items =
            routeData?.items ??
            (extra is List
                ? extra.whereType<CheckoutItemData>().toList(growable: false)
                : const <CheckoutItemData>[]);

        Widget buildCheckout(List<CheckoutAddressData> addresses) {
          CheckoutAddressData? defaultAddress;
          for (final CheckoutAddressData address in addresses) {
            if (address.isDefault) {
              defaultAddress = address;
              break;
            }
          }
          defaultAddress ??= addresses.isEmpty ? null : addresses.first;
          return CheckoutScreen(
            checkoutToken: 'laravel-buyer-checkout',
            items: items,
            addresses: addresses,
            couriersBySeller: const <int, List<CheckoutCourierOption>>{},
            requireCourierSelection: false,
            appliedVoucherCodes:
                routeData?.voucherCodes ?? const <int, String>{},
            loadAvailableVouchers: AppConfig.apiEnabled
                ? () async =>
                      (await BuyerMobileService.fetchRewards()).activeVouchers
                : null,
            initialRecipientName: defaultAddress?.recipient ?? '',
            initialContactNumber: defaultAddress?.phone ?? '',
            onBackToCart: () => safeBack(context, fallback: '/buyer/cart'),
            onPlaceOrder: routeData == null
                ? null
                : (CheckoutPlaceOrderRequest request) async {
                    await BuyerMobileService.placeOrder(
                      cartItemIds: routeData.cartItemIds,
                      addressId: request.addressId,
                      paymentMethod: request.paymentMethod,
                      voucherCodes: request.voucherCodes,
                      sellerNotes: request.notesBySeller,
                      protectedProductIds: request.protectedProductIds,
                    );
                    AppNotificationCenter.showOrderPlaced();
                    if (context.mounted) {
                      context.go('/buyer/orders');
                    }
                  },
          );
        }

        if (!AppConfig.apiEnabled) {
          return buildCheckout(const <CheckoutAddressData>[]);
        }
        if (routeData == null || routeData.cartItemIds.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Checkout requires items selected from your connected cart.',
              ),
            ),
          );
        }
        return AsyncRouteBuilder<List<CheckoutAddressData>>(
          load: () => BuyerMobileService.fetchCheckoutAddresses(),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<CheckoutAddressData>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const RouteLoadingPage(title: 'Checkout');
                }
                if (snapshot.hasError) {
                  return Scaffold(
                    appBar: AppBar(
                      title: const Text('Checkout'),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.go('/buyer/cart'),
                      ),
                    ),
                    body: Center(
                      child: Text(
                        'Unable to load delivery addresses: ${snapshot.error}',
                      ),
                    ),
                  );
                }
                return buildCheckout(
                  snapshot.data ?? const <CheckoutAddressData>[],
                );
              },
        );
      },
    ),

    GoRoute(
      path: '/buyer/rewards',
      name: 'buyer-rewards',
      builder: (BuildContext context, GoRouterState state) {
        RewardsScreen buildRewards(RewardsData data) => RewardsScreen(
          activeVouchers: data.activeVouchers,
          voucherHistory: data.voucherHistory,
          pointsBalance: data.pointsBalance,
          pointActivities: data.pointActivities,
          availableCashback: data.availableCashback,
          pendingCashback: data.pendingCashback,
          cashbackActivities: data.cashbackActivities,
          pointsPerCompletedOrder: data.pointsPerCompletedOrder,
          pointsPerReview: data.pointsPerReview,
          cashbackRate: data.cashbackRate,
          onBack: () => safeBack(context, fallback: '/buyer/home'),
          onBrowseProducts: () => context.push('/buyer/products'),
          onRefresh: AppConfig.apiEnabled
              ? BuyerMobileService.fetchRewards
              : null,
          onUseVoucher: (RewardVoucherData voucher) {
            if (voucher.sellerId == null || voucher.code.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'This voucher cannot be applied automatically.',
                  ),
                ),
              );
              return;
            }
            context.push(
              '/buyer/cart',
              extra: <int, String>{voucher.sellerId!: voucher.code},
            );
          },
        );

        if (!AppConfig.apiEnabled) {
          return RewardsScreen(
            onBack: () => safeBack(context, fallback: '/buyer/home'),
            onBrowseProducts: () => context.push('/buyer/products'),
          );
        }
        return AsyncRouteBuilder<RewardsData>(
          load: () => BuyerMobileService.fetchRewards(),
          refreshOnActivate: true,
          builder: (BuildContext context, AsyncSnapshot<RewardsData> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const RouteLoadingPage(title: 'Rewards');
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Rewards'),
                  leading: IconButton(
                    onPressed: () => safeBack(context, fallback: '/buyer/home'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                body: Center(
                  child: Text('Unable to load rewards: ${snapshot.error}'),
                ),
              );
            }
            return buildRewards(snapshot.data!);
          },
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
      path: '/buyer/settings',
      name: 'buyer-settings',
      builder: (BuildContext context, GoRouterState state) {
        return _buyerNavigationFrame(
          context,
          currentIndex: 3,
          aiPage: 'account',
          aiPageTitle: 'System Settings',
          child: BuyerSystemSettingsScreen(
            onBack: () => safeBack(context, fallback: '/buyer/profile'),
            onMyAccount: () => context.go('/buyer/profile'),
          ),
        );
      },
    ),

    GoRoute(
      path: '/rider/settings',
      name: 'rider-settings',
      builder: (BuildContext context, GoRouterState state) {
        return _riderNavigationFrame(
          context,
          currentIndex: 4,
          child: BuyerSystemSettingsScreen(
            riderMode: true,
            onBack: () => safeBack(context, fallback: '/rider/profile'),
          ),
        );
      },
    ),

    GoRoute(
      path: '/rider/dashboard',
      name: 'rider-dashboard',
      builder: (BuildContext context, GoRouterState state) {
        return _riderNavigationFrame(
          context,
          currentIndex: 0,
          child: AppConfig.apiEnabled
              ? RiderApiLoader<RiderDashboardSnapshot>(
                  load: RiderMobileService.fetchDashboard,
                  builder:
                      (
                        BuildContext context,
                        RiderDashboardSnapshot? data,
                        Object? error,
                        Future<void> Function() refresh,
                      ) => RiderDashboardScreen(
                        riderName: data?.riderName ?? '',
                        onOpenPickups: () => context.go('/rider/pickups'),
                        onOpenEarnings: () => context.go('/rider/earnings'),
                        stats: data?.stats ?? const <RiderDashboardStatData>[],
                        recentParcels:
                            data?.recentParcels ??
                            const <RiderDashboardParcelData>[],
                        statusMessage: error?.toString(),
                        onRefresh: refresh,
                        onOpenScanner: () => context.push('/rider/scanner'),
                        onOpenMessages: () => context.push('/rider/messages'),
                        onOpenNotifications: () =>
                            context.push('/rider/notifications'),
                        onViewAllShipments: () =>
                            context.go('/rider/assignments'),
                        onViewParcel: (RiderDashboardParcelData parcel) {
                          context.push(
                            '/rider/delivery-details',
                            extra: RiderDeliveryData(
                              id: parcel.id,
                              trackingCode: parcel.trackingCode,
                              buyerName: parcel.buyerName,
                              contact: parcel.contact,
                              address: parcel.address,
                              amount: parcel.amount,
                              status: parcel.status,
                              statusLabel: parcel.statusLabel,
                              imageUrl: parcel.imageUrl,
                              deliveryLatitude: parcel.deliveryLatitude,
                              deliveryLongitude: parcel.deliveryLongitude,
                              isPreview: parcel.isPreview,
                            ),
                          );
                        },
                      ),
                )
              : RiderDashboardScreen(
                  onOpenPickups: () => context.go('/rider/pickups'),
                  onOpenEarnings: () => context.go('/rider/earnings'),
                  onOpenScanner: () => context.push('/rider/scanner'),
                  onOpenMessages: () => context.push('/rider/messages'),
                  onOpenNotifications: () =>
                      context.push('/rider/notifications'),
                  onViewAllShipments: () => context.go('/rider/assignments'),
                  onViewParcel: (RiderDashboardParcelData parcel) {
                    context.push(
                      '/rider/delivery-details',
                      extra: RiderDeliveryData(
                        id: parcel.id,
                        trackingCode: parcel.trackingCode,
                        buyerName: parcel.buyerName,
                        contact: parcel.contact,
                        address: parcel.address,
                        amount: parcel.amount,
                        status: parcel.status,
                        statusLabel: parcel.statusLabel,
                        imageUrl: parcel.imageUrl,
                        deliveryLatitude: parcel.deliveryLatitude,
                        deliveryLongitude: parcel.deliveryLongitude,
                        isPreview: parcel.isPreview,
                      ),
                    );
                  },
                ),
        );
      },
    ),

    GoRoute(
      path: '/rider/notifications',
      name: 'rider-notifications',
      builder: (BuildContext context, GoRouterState state) {
        return _riderNavigationFrame(
          context,
          currentIndex: 0,
          child: AsyncRouteBuilder<List<BuyerNotificationData>>(
            load: () => AppConfig.apiEnabled
                ? RiderMobileService.fetchNotifications()
                : Future<List<BuyerNotificationData>>.value(
                    const <BuyerNotificationData>[],
                  ),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<BuyerNotificationData>> snapshot,
                ) {
                  return NotificationsScreen(
                    notifications:
                        snapshot.data ?? const <BuyerNotificationData>[],
                    onBack: () =>
                        safeBack(context, fallback: '/rider/dashboard'),
                    onRefresh: AppConfig.apiEnabled
                        ? RiderMobileService.fetchNotifications
                        : null,
                    realtimeStreamBuilder: AppConfig.realtimeEnabled
                        ? BuyerMobileService.watchNotifications
                        : null,
                    onMarkAllAsRead: AppConfig.apiEnabled
                        ? RiderMobileService.markAllNotificationsRead
                        : null,
                  );
                },
          ),
        );
      },
    ),

    GoRoute(
      path: '/rider/assignments',
      name: 'rider-assignments',
      builder: (BuildContext context, GoRouterState state) {
        return _riderNavigationFrame(
          context,
          currentIndex: 1,
          child: AppConfig.apiEnabled
              ? RiderApiLoader<RiderAssignmentsSnapshot>(
                  load: RiderMobileService.fetchAssignments,
                  refreshInterval: const Duration(seconds: 15),
                  builder:
                      (
                        BuildContext context,
                        RiderAssignmentsSnapshot? data,
                        Object? error,
                        Future<void> Function() refresh,
                      ) => RiderDeliveriesScreen(
                        deliveries:
                            data?.deliveries ?? const <RiderDeliveryData>[],
                        stats: data?.stats,
                        statusMessage: error?.toString(),
                        showPreviewWhenEmpty: false,
                        onRefresh: refresh,
                        onBack: () =>
                            safeBack(context, fallback: '/rider/dashboard'),
                        onViewDelivery: (RiderDeliveryData delivery) {
                          context.push(
                            '/rider/delivery-details',
                            extra: delivery,
                          );
                        },
                      ),
                )
              : RiderDeliveriesScreen(
                  onBack: () => safeBack(context, fallback: '/rider/dashboard'),
                  onViewDelivery: (RiderDeliveryData delivery) {
                    context.push('/rider/delivery-details', extra: delivery);
                  },
                ),
        );
      },
    ),

    GoRoute(
      path: '/rider/pickups',
      name: 'rider-pickups',
      builder: (BuildContext context, GoRouterState state) {
        return _riderNavigationFrame(
          context,
          currentIndex: 1,
          child: AppConfig.apiEnabled
              ? RiderApiLoader<RiderPickupsSnapshot>(
                  load: RiderMobileService.fetchPickups,
                  builder:
                      (
                        BuildContext context,
                        RiderPickupsSnapshot? data,
                        Object? error,
                        Future<void> Function() refresh,
                      ) => RiderPickupsScreen(
                        pickups: data?.pickups ?? const <RiderPickupData>[],
                        stats:
                            data?.stats ??
                            const RiderPickupStatsData(
                              ready: 0,
                              accepted: 0,
                              pickedUp: 0,
                            ),
                        statusMessage: error?.toString(),
                        onRefresh: refresh,
                        onViewDeliveries: () =>
                            context.push('/rider/assignments'),
                        onViewPickup: (RiderPickupData pickup) async {
                          final bool? changed = await context.push<bool>(
                            '/rider/pickup-details',
                            extra: pickup,
                          );
                          if (changed == true) await refresh();
                        },
                      ),
                )
              : RiderPickupsScreen(
                  onViewDeliveries: () => context.push('/rider/assignments'),
                  onViewPickup: (RiderPickupData pickup) async {
                    await context.push<bool>(
                      '/rider/pickup-details',
                      extra: pickup,
                    );
                  },
                ),
        );
      },
    ),

    GoRoute(
      path: '/rider/pickup-details',
      name: 'rider-pickup-details',
      builder: (BuildContext context, GoRouterState state) {
        final dynamic extra = state.extra;

        if (extra is! RiderPickupData) {
          return _riderScreenPresentation(
            context,
            child: Scaffold(
              appBar: AppBar(title: const Text('Pickup Details')),
              body: const Center(
                child: Text('Pickup information is unavailable.'),
              ),
            ),
          );
        }

        final Widget details = extra.isBatch
            ? RiderPickupBatchDetailsScreen(
                batch: extra,
                onAccept: AppConfig.apiEnabled
                    ? RiderMobileService.acceptPickupBatch
                    : null,
                onStart: AppConfig.apiEnabled
                    ? RiderMobileService.startPickupBatch
                    : null,
                onScan: AppConfig.apiEnabled
                    ? (int batchId, String code, String method) =>
                          RiderMobileService.scanPickupBatch(
                            batchId,
                            code,
                            scanMethod: method,
                          )
                    : null,
                onNotCollected: AppConfig.apiEnabled
                    ? RiderMobileService.markPickupNotCollected
                    : null,
                onFinish: AppConfig.apiEnabled
                    ? RiderMobileService.finishPickupBatch
                    : null,
                onReload: AppConfig.apiEnabled
                    ? RiderMobileService.fetchPickupBatch
                    : null,
              )
            : RiderPickupDetailsScreen(
                pickup: extra,
                onTransition: AppConfig.apiEnabled
                    ? RiderMobileService.transitionPickup
                    : null,
                onVerifyTracking: AppConfig.apiEnabled
                    ? RiderMobileService.verifyPickup
                    : null,
                onBack: () => safeBack(context, fallback: '/rider/pickups'),
                onBackToPickups: () =>
                    safeBack(context, fallback: '/rider/pickups'),
              );
        return _riderScreenPresentation(context, child: details);
      },
    ),

    GoRoute(
      path: '/rider/history',
      name: 'rider-history',
      builder: (BuildContext context, GoRouterState state) {
        return _riderNavigationFrame(
          context,
          currentIndex: 2,
          child: AppConfig.apiEnabled
              ? RiderApiLoader<List<RiderHistoryData>>(
                  load: RiderMobileService.fetchHistory,
                  builder:
                      (
                        BuildContext context,
                        List<RiderHistoryData>? data,
                        Object? error,
                        Future<void> Function() refresh,
                      ) => RiderHistoryScreen(
                        history: data ?? const <RiderHistoryData>[],
                        statusMessage: error?.toString(),
                        onRefresh: refresh,
                      ),
                )
              : const RiderHistoryScreen(),
        );
      },
    ),

    GoRoute(
      path: '/rider/messages',
      name: 'rider-messages',
      builder: (BuildContext context, GoRouterState state) {
        return _riderNavigationFrame(
          context,
          currentIndex: -1,
          child: AppConfig.apiEnabled
              ? RiderApiLoader<List<RiderConversationData>>(
                  load: RiderMobileService.fetchConversations,
                  builder:
                      (
                        BuildContext context,
                        List<RiderConversationData>? data,
                        Object? error,
                        Future<void> Function() refresh,
                      ) => RiderMessagesScreen(
                        conversations: data ?? const <RiderConversationData>[],
                        onRefresh: RiderMobileService.fetchConversations,
                        onLoadMessages: RiderMobileService.fetchMessages,
                        onSendMessage: RiderMobileService.sendMessage,
                        messageStreamBuilder: RiderMobileService.watchMessages,
                        onPresenceHeartbeat:
                            RiderMobileService.touchMessagePresence,
                        statusMessage: error?.toString(),
                        onBack: () =>
                            safeBack(context, fallback: '/rider/dashboard'),
                      ),
                )
              : RiderMessagesScreen(
                  onBack: () => safeBack(context, fallback: '/rider/dashboard'),
                ),
        );
      },
    ),

    GoRoute(
      path: '/rider/earnings',
      name: 'rider-earnings',
      builder: (BuildContext context, GoRouterState state) {
        return _riderNavigationFrame(
          context,
          currentIndex: 3,
          child: AppConfig.apiEnabled
              ? RiderApiLoader<RiderEarningsSnapshot>(
                  load: RiderMobileService.fetchEarnings,
                  builder:
                      (
                        BuildContext context,
                        RiderEarningsSnapshot? data,
                        Object? error,
                        Future<void> Function() refresh,
                      ) => RiderEarningsScreen(
                        earningsRows:
                            data?.rows ?? const <RiderEarningRowData>[],
                        summary: data?.summary,
                        riderName: data?.riderName ?? '',
                        earningsNotice:
                            error?.toString() ??
                            data?.notice ??
                            'No earnings records are available.',
                        onRefresh: refresh,
                      ),
                )
              : const RiderEarningsScreen(),
        );
      },
    ),

    GoRoute(
      path: '/rider/profile',
      name: 'rider-profile',
      builder: (BuildContext context, GoRouterState state) {
        return _riderNavigationFrame(
          context,
          currentIndex: 4,
          child: AppConfig.apiEnabled
              ? RiderApiLoader<RiderProfileData>(
                  load: RiderMobileService.fetchProfile,
                  builder:
                      (
                        BuildContext context,
                        RiderProfileData? data,
                        Object? error,
                        Future<void> Function() refresh,
                      ) => RiderProfileScreen(
                        profile: data,
                        statusMessage: error?.toString(),
                        onRefresh: refresh,
                        onSystemSettings: () => context.push('/rider/settings'),
                        onEditProfile: () async {
                          await context.push<bool>(
                            '/rider/profile/edit',
                            extra: data,
                          );
                          await refresh();
                        },
                        onLogout: () async {
                          await AuthService.logout();
                          if (context.mounted) {
                            context.go('/login');
                          }
                        },
                      ),
                )
              : AsyncRouteBuilder<AuthUserModel>(
                  load: () => AuthService.getCurrentUser(),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<AuthUserModel> snapshot,
                      ) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const RouteLoadingPage(title: 'Profile');
                        }

                        final AuthUserModel? user = snapshot.data;

                        return RiderProfileScreen(
                          profile: user == null
                              ? null
                              : RiderProfileData(
                                  id: user.id,
                                  name: user.name,
                                  email: user.email ?? 'Not recorded',
                                  contactNumber:
                                      user.contactNumber ?? 'Not recorded',
                                  birthday: 'Not recorded',
                                  sex: 'Not recorded',
                                  address: 'Not recorded',
                                  vehicleType: 'Not recorded',
                                  plateNumber: 'Not recorded',
                                  status: user.status ?? 'Active',
                                  primaryRole: 'Rider',
                                ),
                          onLogout: () async {
                            await AuthService.logout();
                            if (context.mounted) {
                              context.go('/login');
                            }
                          },
                          onSystemSettings: () =>
                              context.push('/rider/settings'),
                        );
                      },
                ),
        );
      },
    ),

    GoRoute(
      path: '/rider/profile/edit',
      name: 'rider-profile-edit',
      builder: (BuildContext context, GoRouterState state) {
        final dynamic profile = state.extra;
        if (profile is! RiderProfileData) {
          return _riderNavigationFrame(
            context,
            currentIndex: 4,
            child: const Scaffold(
              body: Center(child: Text('Rider profile data is unavailable.')),
            ),
          );
        }
        return _riderNavigationFrame(
          context,
          currentIndex: 4,
          child: RiderProfileEditScreen(profile: profile),
        );
      },
    ),

    GoRoute(
      path: '/rider/delivery-details',
      name: 'rider-delivery-details',
      builder: (BuildContext context, GoRouterState state) {
        final dynamic extra = state.extra;
        final RiderDeliveryData? delivery = extra is RiderDeliveryData
            ? extra
            : null;

        return _riderScreenPresentation(
          context,
          child: RiderDeliveryDetailsScreen(
            delivery: delivery,
            showPreviewWhenNull: !AppConfig.apiEnabled,
            onTransition: AppConfig.apiEnabled
                ? RiderMobileService.transitionDelivery
                : null,
            onBackToDeliveries: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/rider/assignments');
              }
            },
            onViewTracking: (RiderDeliveryData selectedDelivery) {
              context.push('/rider/delivery-tracking', extra: selectedDelivery);
            },
          ),
        );
      },
    ),

    GoRoute(
      path: '/rider/delivery-tracking',
      name: 'rider-delivery-tracking',
      builder: (BuildContext context, GoRouterState state) {
        final dynamic extra = state.extra;

        return _riderScreenPresentation(
          context,
          child: RiderDeliveryTrackingScreen(
            delivery: extra is RiderDeliveryData ? extra : null,
            showPreviewWhenNull: !AppConfig.apiEnabled,
            onTransition: AppConfig.apiEnabled
                ? RiderMobileService.transitionDelivery
                : null,
            onOpenDetails: (RiderDeliveryData delivery) {
              context.push('/rider/delivery-details', extra: delivery);
            },
          ),
        );
      },
    ),

    GoRoute(
      path: '/rider/scanner',
      name: 'rider-scanner',
      builder: (BuildContext context, GoRouterState state) {
        return _riderScreenPresentation(
          context,
          child: RiderScannerScreen(
            onSignOut: () async {
              await AuthService.logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        );
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
