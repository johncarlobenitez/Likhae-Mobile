import 'package:flutter/material.dart';
import 'package:likhae/features/buyer/products/products_screen.dart';

enum BuyerOrdersMode { overview, success, details, review, returnRequest }

enum BuyerOrderTab {
  all,
  toPay,
  toShip,
  toReceive,
  completed,
  cancelled,
  returns,
}

extension BuyerOrderTabInfo on BuyerOrderTab {
  String get statusKey {
    switch (this) {
      case BuyerOrderTab.all:
        return 'all';

      case BuyerOrderTab.toPay:
        return 'to-pay';

      case BuyerOrderTab.toShip:
        return 'to-ship';

      case BuyerOrderTab.toReceive:
        return 'to-receive';

      case BuyerOrderTab.completed:
        return 'completed';

      case BuyerOrderTab.cancelled:
        return 'cancelled';

      case BuyerOrderTab.returns:
        return 'returns';
    }
  }

  String get label {
    switch (this) {
      case BuyerOrderTab.all:
        return 'All';

      case BuyerOrderTab.toPay:
        return 'To Pay';

      case BuyerOrderTab.toShip:
        return 'To Ship';

      case BuyerOrderTab.toReceive:
        return 'To Receive';

      case BuyerOrderTab.completed:
        return 'Completed';

      case BuyerOrderTab.cancelled:
        return 'Cancelled';

      case BuyerOrderTab.returns:
        return 'Returns / Refunds';
    }
  }
}

class BuyerOrderProductData {
  final String id;

  final int? productId;
  final int? productVariationId;

  final String name;

  final String? variant;
  final String? imageUrl;

  final double price;

  final int quantity;

  const BuyerOrderProductData({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.productId,
    this.productVariationId,
    this.variant,
    this.imageUrl,
  });

  int get safeQuantity {
    return quantity < 1 ? 1 : quantity;
  }

  double get lineTotal {
    return price * safeQuantity;
  }
}

class BuyerOrderTimelineEvent {
  final String label;

  final String time;

  final bool done;

  const BuyerOrderTimelineEvent({
    required this.label,
    required this.time,
    required this.done,
  });
}

class BuyerOrderLocation {
  final double latitude;

  final double longitude;

  final String label;

  const BuyerOrderLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
  });
}

class BuyerOrderData {
  final String id;

  /// Buyer-facing grouping key:
  ///
  /// to-pay
  /// to-ship
  /// to-receive
  /// completed
  /// cancelled
  /// returns
  ///
  /// This is intentionally separate from [backendStatus].
  final String status;

  /// Actual Laravel order/workflow status when available.
  ///
  /// Examples:
  /// pending
  /// placed
  /// confirmed
  /// preparing
  /// shipping
  /// shipped
  /// delivered
  /// completed
  /// cancelled
  /// returns
  final String? backendStatus;

  final String statusLabel;

  final String payment;

  final String? paymentStatus;

  final List<BuyerOrderProductData> products;

  final double total;

  final String buyerName;
  final String? buyerContact;

  final String shippingAddress;

  final String? tracking;

  final BuyerOrderLocation? orderLocation;

  final List<BuyerOrderTimelineEvent> timeline;

  final DateTime? createdAt;

  /// True only for UI preview orders generated from ProductsScreen.
  /// Preview orders are never submitted to Laravel and expose no actions.
  final bool isPreview;

  /// Optional explicit capability flags.
  ///
  /// Once Laravel mobile APIs exist, these are the safest
  /// values to return because the server remains the source
  /// of truth for which actions are currently allowed.
  final bool? allowCancel;
  final bool? allowMarkReceived;
  final bool? allowReview;
  final bool? allowReturnRequest;

  const BuyerOrderData({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.payment,
    required this.products,
    required this.total,
    required this.buyerName,
    required this.shippingAddress,
    this.backendStatus,
    this.paymentStatus,
    this.buyerContact,
    this.tracking,
    this.orderLocation,
    this.timeline = const <BuyerOrderTimelineEvent>[],
    this.createdAt,
    this.isPreview = false,
    this.allowCancel,
    this.allowMarkReceived,
    this.allowReview,
    this.allowReturnRequest,
  });

  factory BuyerOrderData.fromApi(Map<String, dynamic> json) {
    BuyerOrderLocation? parseLocation(dynamic raw, String label) {
      if (raw is! Map) {
        return null;
      }

      final Map<String, dynamic> location = Map<String, dynamic>.from(raw);
      final double? latitude = double.tryParse(
        (location['latitude'] ?? location['lat'] ?? '').toString(),
      );
      final double? longitude = double.tryParse(
        (location['longitude'] ?? location['lng'] ?? location['lon'] ?? '')
            .toString(),
      );

      if (latitude == null || longitude == null) {
        return null;
      }

      return BuyerOrderLocation(
        latitude: latitude,
        longitude: longitude,
        label: label,
      );
    }

    final dynamic rawBuyer = json['buyer'] ?? json['user'];
    final Map<String, dynamic> buyer = rawBuyer is Map
        ? Map<String, dynamic>.from(rawBuyer)
        : const <String, dynamic>{};
    final dynamic rawItems =
        json['items'] ?? json['order_items'] ?? json['products'];
    final List<BuyerOrderProductData> products = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((Map item) {
                final Map<String, dynamic> product = Map<String, dynamic>.from(
                  item,
                );
                final dynamic nestedProduct = product['product'];
                final Map<String, dynamic> details = nestedProduct is Map
                    ? Map<String, dynamic>.from(nestedProduct)
                    : product;

                return BuyerOrderProductData(
                  id: (product['id'] ?? details['id'] ?? '').toString(),
                  productId: int.tryParse(
                    (product['product_id'] ??
                            details['product_id'] ??
                            details['id'] ??
                            '')
                        .toString(),
                  ),
                  name: (product['name'] ?? details['name'] ?? 'Product')
                      .toString(),
                  variant: product['variant']?.toString(),
                  imageUrl:
                      (product['image_url'] ??
                              details['image_url'] ??
                              details['image'])
                          ?.toString(),
                  price:
                      double.tryParse(
                        (product['price'] ?? product['unit_price'] ?? 0)
                            .toString(),
                      ) ??
                      0,
                  quantity:
                      int.tryParse((product['quantity'] ?? 1).toString()) ?? 1,
                );
              })
              .toList(growable: false)
        : const <BuyerOrderProductData>[];

    final dynamic rawAddress = json['shipping_address'] ?? json['address'];
    final String address = rawAddress is Map
        ? <dynamic>[
                rawAddress['house_number'],
                rawAddress['street'],
                rawAddress['barangay'],
                rawAddress['municipality'],
                rawAddress['province'],
                rawAddress['postal_code'],
              ]
              .where(
                (dynamic value) =>
                    value != null && value.toString().trim().isNotEmpty,
              )
              .join(', ')
        : (rawAddress ?? '').toString();
    final String backendStatus =
        (json['status'] ?? json['order_status'] ?? 'pending').toString();

    return BuyerOrderData(
      id: (json['id'] ?? json['order_number'] ?? '').toString(),
      status: (json['buyer_status'] ?? backendStatus).toString(),
      backendStatus: backendStatus,
      statusLabel: (json['status_label'] ?? backendStatus).toString(),
      payment: (json['payment_method'] ?? json['payment'] ?? 'Not specified')
          .toString(),
      paymentStatus: json['payment_status']?.toString(),
      products: products,
      total:
          double.tryParse(
            (json['total'] ?? json['grand_total'] ?? json['order_total'] ?? 0)
                .toString(),
          ) ??
          0,
      buyerName: (json['buyer_name'] ?? buyer['name'] ?? '').toString(),
      buyerContact: (json['buyer_contact'] ?? buyer['contact_number'])
          ?.toString(),
      shippingAddress: address,
      tracking: (json['tracking_number'] ?? json['tracking'])?.toString(),
      orderLocation: parseLocation(
        json['order_location'] ??
            json['shipment_location'] ??
            json['current_order_location'],
        'Order location',
      ),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      allowCancel: json['allow_cancel'] as bool?,
      allowMarkReceived: json['allow_mark_received'] as bool?,
      allowReview: json['allow_review'] as bool?,
      allowReturnRequest: json['allow_return_request'] as bool?,
    );
  }

  String get normalizedStatus {
    return (backendStatus ?? status)
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  String get tabStatus {
    final String buyerStatus = status.trim().toLowerCase();

    const Set<String> supported = <String>{
      'to-pay',
      'to-ship',
      'to-receive',
      'completed',
      'cancelled',
      'returns',
    };

    if (supported.contains(buyerStatus)) {
      return buyerStatus;
    }

    switch (normalizedStatus) {
      case 'pending':
      case 'placed':
        return 'to-pay';

      case 'confirmed':
      case 'preparing':
      case 'ready_for_pickup':
        return 'to-ship';

      case 'shipping':
      case 'shipped':
      case 'in_transit':
      case 'out_for_delivery':
      case 'delivered':
        return 'to-receive';

      case 'completed':
        return 'completed';

      case 'cancelled':
      case 'canceled':
        return 'cancelled';

      case 'returns':
      case 'return_requested':
      case 'refund_requested':
      case 'returned':
      case 'refunded':
        return 'returns';

      default:
        return buyerStatus;
    }
  }

  bool get canCancel {
    if (allowCancel != null) {
      return allowCancel!;
    }

    const Set<String> cancellable = <String>{
      'pending',
      'to_process',
      'placed',
      'confirmed',
      'preparing',
    };

    if (backendStatus != null) {
      return cancellable.contains(normalizedStatus);
    }

    /// Compatibility with the first Flutter page before the
    /// backend status is exposed to mobile.
    return status == 'to-pay';
  }

  bool get canMarkReceived {
    if (allowMarkReceived != null) {
      return allowMarkReceived!;
    }

    /// Laravel should only allow this when delivery has
    /// actually reached delivered.
    return normalizedStatus == 'delivered';
  }

  bool get canReview {
    if (allowReview != null) {
      return allowReview!;
    }

    return normalizedStatus == 'completed' || status == 'completed';
  }

  bool get canRequestReturn {
    if (allowReturnRequest != null) {
      return allowReturnRequest!;
    }

    const Set<String> eligible = <String>{'shipping', 'shipped', 'completed'};

    return eligible.contains(normalizedStatus);
  }

  BuyerOrderData copyWith({
    String? status,
    String? backendStatus,
    String? statusLabel,
    String? paymentStatus,
    bool? allowCancel,
    bool? allowMarkReceived,
    bool? allowReview,
    bool? allowReturnRequest,
    bool? isPreview,
  }) {
    return BuyerOrderData(
      id: id,
      status: status ?? this.status,
      backendStatus: backendStatus ?? this.backendStatus,
      statusLabel: statusLabel ?? this.statusLabel,
      payment: payment,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      products: products,
      total: total,
      buyerName: buyerName,
      buyerContact: buyerContact,
      shippingAddress: shippingAddress,
      tracking: tracking,
      orderLocation: orderLocation,
      timeline: timeline,
      createdAt: createdAt,
      isPreview: isPreview ?? this.isPreview,
      allowCancel: allowCancel ?? this.allowCancel,
      allowMarkReceived: allowMarkReceived ?? this.allowMarkReceived,
      allowReview: allowReview ?? this.allowReview,
      allowReturnRequest: allowReturnRequest ?? this.allowReturnRequest,
    );
  }
}

class BuyerOrderReviewRequest {
  final BuyerOrderData order;

  final BuyerOrderProductData product;

  final int rating;

  final String review;

  const BuyerOrderReviewRequest({
    required this.order,
    required this.product,
    required this.rating,
    required this.review,
  });
}

class BuyerOrderReturnRequest {
  final BuyerOrderData order;

  final String requestType;

  final String reason;

  final String details;

  const BuyerOrderReturnRequest({
    required this.order,
    required this.requestType,
    required this.reason,
    required this.details,
  });
}

typedef CancelOrderCallback =
    Future<void> Function(BuyerOrderData order, String reason, String note);

typedef ReceiveOrderCallback = Future<void> Function(BuyerOrderData order);

/// Legacy callback kept so existing page wiring does not
/// immediately break.
typedef SubmitReviewCallback =
    Future<void> Function(BuyerOrderData order, int rating, String review);

/// Preferred product-specific review callback.
typedef SubmitProductReviewCallback =
    Future<void> Function(BuyerOrderReviewRequest request);

/// Legacy callback.
typedef SubmitReturnCallback =
    Future<void> Function(
      BuyerOrderData order,
      String requestType,
      String reason,
      String details,
    );

/// Preferred request-object callback.
typedef SubmitOrderReturnCallback =
    Future<void> Function(BuyerOrderReturnRequest request);

typedef BuyerOrderCallback = void Function(BuyerOrderData order);

typedef OrdersRefreshCallback = Future<void> Function();

class OrdersScreen extends StatefulWidget {
  final List<BuyerOrderData> orders;

  /// Optional catalog products from ProductsScreen.
  ///
  /// If [orders] is empty and this list is supplied, these products can
  /// populate the preview cards. If it is empty too, the screen falls back
  /// to built-in sample orders so the final Orders UI can still be inspected
  /// before the Laravel mobile orders API/database wiring is finished.
  final List<BuyerProduct> previewProducts;

  /// Set to false once you want a truly empty state instead of sample orders.
  final bool showProductPreviewWhenEmpty;

  final BuyerOrdersMode initialMode;

  final String? selectedOrderId;

  final BuyerOrderTab initialTab;

  final String? buyerNotice;

  final VoidCallback? onBack;
  final VoidCallback? onShopProducts;

  final BuyerOrderCallback? onTrackOrder;

  final CancelOrderCallback? onCancelOrder;
  final ReceiveOrderCallback? onReceiveOrder;

  /// Legacy order-level review callback.
  final SubmitReviewCallback? onSubmitReview;

  /// Preferred callback because reviews belong to a specific
  /// product inside the order.
  final SubmitProductReviewCallback? onSubmitProductReview;

  /// Legacy return callback.
  final SubmitReturnCallback? onSubmitReturn;

  /// Preferred return request callback.
  final SubmitOrderReturnCallback? onSubmitReturnRequest;

  final OrdersRefreshCallback? onRefresh;

  const OrdersScreen({
    super.key,
    this.orders = const <BuyerOrderData>[],
    this.previewProducts = const <BuyerProduct>[],
    this.showProductPreviewWhenEmpty = true,
    this.initialMode = BuyerOrdersMode.overview,
    this.selectedOrderId,
    this.initialTab = BuyerOrderTab.all,
    this.buyerNotice,
    this.onBack,
    this.onShopProducts,
    this.onTrackOrder,
    this.onCancelOrder,
    this.onReceiveOrder,
    this.onSubmitReview,
    this.onSubmitProductReview,
    this.onSubmitReturn,
    this.onSubmitReturnRequest,
    this.onRefresh,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const Color _background = Color(0xFFFBF7F2);

  static const Color _surface = Color(0xFFFFFDF9);

  static const Color _soft = Color(0xFFF6EFE7);

  static const Color _border = Color(0xFFEADCCC);

  static const Color _maroon = Color(0xFF561C17);

  static const Color _maroonDark = Color(0xFF3E130F);

  static const Color _text = Color(0xFF3B211B);

  static const Color _muted = Color(0xFF987865);

  static const Color _muted2 = Color(0xFFA99386);

  static const Color _tan = Color(0xFFC19771);

  static const Color _danger = Color(0xFFB42318);

  static const Color _star = Color(0xFFC88418);

  late List<BuyerOrderData> _orders;

  late BuyerOrdersMode _mode;
  late BuyerOrderTab _activeTab;

  String? _selectedOrderId;

  String? _selectedReviewProductId;

  bool _receivingOrder = false;
  bool _submittingReview = false;
  bool _submittingReturn = false;

  final GlobalKey<FormState> _reviewFormKey = GlobalKey<FormState>();

  final GlobalKey<FormState> _returnFormKey = GlobalKey<FormState>();

  final TextEditingController _reviewController = TextEditingController();

  final TextEditingController _returnDetailsController =
      TextEditingController();

  int _rating = 5;

  String? _returnRequestType;
  String? _returnReason;

  final Set<String> _reviewedProductIds = <String>{};

  final List<String> _returnTypes = const <String>[
    'Return and refund',
    'Refund only',
  ];

  final List<String> _returnReasons = const <String>[
    'Damaged item',
    'Defective item',
    'Wrong product',
    'Wrong variation',
    'Missing item',
    'Missing parts',
    'Significantly different from description',
    'Other',
  ];

  final List<String> _cancelReasons = const <String>[
    'Changed my mind',
    'Need to change address',
    'Found a better option',
    'Payment issue',
    'Ordered by mistake',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    _orders = _resolveInitialOrders();

    _mode = widget.initialMode;

    _activeTab = widget.initialTab;

    _selectedOrderId = widget.selectedOrderId;

    _syncSelectedReviewProduct();
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.orders != widget.orders ||
        oldWidget.previewProducts != widget.previewProducts ||
        oldWidget.showProductPreviewWhenEmpty !=
            widget.showProductPreviewWhenEmpty) {
      _orders = _resolveInitialOrders();

      _syncSelectedReviewProduct();
    }

    if (oldWidget.selectedOrderId != widget.selectedOrderId) {
      _selectedOrderId = widget.selectedOrderId;

      _syncSelectedReviewProduct();
    }

    if (oldWidget.initialMode != widget.initialMode) {
      _mode = widget.initialMode;
    }

    if (oldWidget.initialTab != widget.initialTab) {
      _activeTab = widget.initialTab;
    }
  }

  bool get _usingProductPreview {
    return widget.orders.isEmpty && widget.showProductPreviewWhenEmpty;
  }

  List<BuyerOrderData> _resolveInitialOrders() {
    if (widget.orders.isNotEmpty) {
      return List<BuyerOrderData>.from(widget.orders);
    }

    if (!widget.showProductPreviewWhenEmpty) {
      return <BuyerOrderData>[];
    }

    if (widget.previewProducts.isNotEmpty) {
      return _buildProductPreviewOrders(widget.previewProducts);
    }

    return _buildBuiltInPreviewOrders();
  }

  List<BuyerOrderData> _buildProductPreviewOrders(List<BuyerProduct> products) {
    final List<BuyerProduct> preview = products.take(5).toList(growable: false);

    return List<BuyerOrderData>.generate(preview.length, (int index) {
      final BuyerProduct product = preview[index];

      final bool completed = index == 4;

      final DateTime placedAt = DateTime(
        2026,
        9,
        24 - index,
        index == 3 ? 7 : 13,
        index == 3 ? 14 : 31,
      );

      return BuyerOrderData(
        id: '${5 - index}',
        status: completed ? 'completed' : 'to-ship',
        backendStatus: completed ? 'completed' : 'preparing',
        statusLabel: completed ? 'Completed' : 'To Ship',
        payment: 'Cash on Delivery',
        products: <BuyerOrderProductData>[
          BuyerOrderProductData(
            id: 'preview-product-${product.id}',
            productId: product.id,
            name: product.name,
            price: product.price,
            quantity: 1,
            imageUrl: product.imageUrl,
            variant: 'Default',
          ),
        ],
        total: product.price + 75,
        buyerName: 'LIKHAE Buyer',
        buyerContact: '0917 123 4567',
        shippingAddress: '1 aaasasa, Masico, Pila, Laguna, 4010',
        timeline: <BuyerOrderTimelineEvent>[
          BuyerOrderTimelineEvent(
            label: 'Order Placed',
            time: _sampleDateTime(placedAt),
            done: true,
          ),
          BuyerOrderTimelineEvent(
            label: completed ? 'Delivered' : 'Pending',
            time: completed
                ? _sampleDateTime(placedAt.add(const Duration(days: 2)))
                : _sampleDateTime(placedAt),
            done: true,
          ),
        ],
        createdAt: placedAt,
        isPreview: true,
        allowCancel: false,
        allowMarkReceived: false,
        allowReview: false,
        allowReturnRequest: false,
      );
    }, growable: false);
  }

  List<BuyerOrderData> _buildBuiltInPreviewOrders() {
    return <BuyerOrderData>[
      BuyerOrderData(
        id: '5',
        status: 'to-ship',
        backendStatus: 'preparing',
        statusLabel: 'To Ship',
        payment: 'Cash on Delivery',
        products: const <BuyerOrderProductData>[
          BuyerOrderProductData(
            id: 'sample-order-5-item-1',
            productId: 101,
            name: 'Gold-Plated Pearl Pendant Necklace',
            variant: 'Finish / Gold',
            imageUrl:
                'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=900&q=85&auto=format&fit=crop',
            price: 890,
            quantity: 1,
          ),
        ],
        total: 965,
        buyerName: 'LIKHAE Buyer',
        buyerContact: '0917 123 4567',
        shippingAddress: '1 aaasasa, Masico, Pila, Laguna, 4010',
        timeline: const <BuyerOrderTimelineEvent>[
          BuyerOrderTimelineEvent(
            label: 'Order Placed',
            time: 'Sep 24, 2026 · 1:31 PM',
            done: true,
          ),
          BuyerOrderTimelineEvent(
            label: 'Pending',
            time: 'Sep 24, 2026 · 1:31 PM',
            done: true,
          ),
        ],
        createdAt: DateTime(2026, 9, 24, 13, 31),
        isPreview: true,
        allowCancel: false,
        allowMarkReceived: false,
        allowReview: false,
        allowReturnRequest: false,
      ),
      BuyerOrderData(
        id: '3',
        status: 'to-ship',
        backendStatus: 'preparing',
        statusLabel: 'To Ship',
        payment: 'Cash on Delivery',
        products: const <BuyerOrderProductData>[
          BuyerOrderProductData(
            id: 'sample-order-3-item-1',
            productId: 102,
            name: 'Creative Journaling Workbook',
            variant: 'Cover / Softcover',
            imageUrl:
                'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=900&q=85&auto=format&fit=crop',
            price: 420,
            quantity: 1,
          ),
        ],
        total: 495,
        buyerName: 'LIKHAE Buyer',
        buyerContact: '0917 123 4567',
        shippingAddress: '1 aaasasa, Masico, Pila, Laguna, 4010',
        timeline: const <BuyerOrderTimelineEvent>[
          BuyerOrderTimelineEvent(
            label: 'Order Placed',
            time: 'Sep 23, 2026 · 3:15 PM',
            done: true,
          ),
          BuyerOrderTimelineEvent(
            label: 'Pending',
            time: 'Sep 23, 2026 · 3:15 PM',
            done: true,
          ),
        ],
        createdAt: DateTime(2026, 9, 23, 15, 15),
        isPreview: true,
        allowCancel: false,
        allowMarkReceived: false,
        allowReview: false,
        allowReturnRequest: false,
      ),
      BuyerOrderData(
        id: '4',
        status: 'to-ship',
        backendStatus: 'preparing',
        statusLabel: 'To Ship',
        payment: 'Cash on Delivery',
        products: const <BuyerOrderProductData>[
          BuyerOrderProductData(
            id: 'sample-order-4-item-1',
            productId: 103,
            name: 'Gold-Plated Pearl Pendant Necklace',
            variant: 'Finish / Gold',
            imageUrl:
                'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=900&q=85&auto=format&fit=crop',
            price: 890,
            quantity: 1,
          ),
        ],
        total: 965,
        buyerName: 'LIKHAE Buyer',
        buyerContact: '0917 123 4567',
        shippingAddress: '1 aaasasa, Masico, Pila, Laguna, 4010',
        timeline: const <BuyerOrderTimelineEvent>[
          BuyerOrderTimelineEvent(
            label: 'Order Placed',
            time: 'Sep 23, 2026 · 3:15 PM',
            done: true,
          ),
          BuyerOrderTimelineEvent(
            label: 'Pending',
            time: 'Sep 23, 2026 · 3:15 PM',
            done: true,
          ),
        ],
        createdAt: DateTime(2026, 9, 23, 15, 15),
        isPreview: true,
        allowCancel: false,
        allowMarkReceived: false,
        allowReview: false,
        allowReturnRequest: false,
      ),
      BuyerOrderData(
        id: '2',
        status: 'to-ship',
        backendStatus: 'preparing',
        statusLabel: 'To Ship',
        payment: 'Cash on Delivery',
        products: const <BuyerOrderProductData>[
          BuyerOrderProductData(
            id: 'sample-order-2-item-1',
            productId: 104,
            name: 'Feeds',
            variant: 'Default',
            imageUrl:
                'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=900&q=85&auto=format&fit=crop',
            price: 123,
            quantity: 1,
          ),
        ],
        total: 198,
        buyerName: 'LIKHAE Buyer',
        buyerContact: '0917 123 4567',
        shippingAddress: '1 aaasasa, Masico, Pila, Laguna, 4010',
        timeline: const <BuyerOrderTimelineEvent>[
          BuyerOrderTimelineEvent(
            label: 'Order Placed',
            time: 'Sep 22, 2026 · 7:14 AM',
            done: true,
          ),
          BuyerOrderTimelineEvent(
            label: 'Pending',
            time: 'Sep 22, 2026 · 7:14 AM',
            done: true,
          ),
        ],
        createdAt: DateTime(2026, 9, 22, 7, 14),
        isPreview: true,
        allowCancel: false,
        allowMarkReceived: false,
        allowReview: false,
        allowReturnRequest: false,
      ),
      BuyerOrderData(
        id: '1',
        status: 'completed',
        backendStatus: 'completed',
        statusLabel: 'Completed',
        payment: 'Cash on Delivery',
        products: const <BuyerOrderProductData>[
          BuyerOrderProductData(
            id: 'sample-order-1-item-1',
            productId: 105,
            name: 'Ergonomic Mesh Office Chair',
            variant: 'Color / Beige',
            imageUrl:
                'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=900&q=85&auto=format&fit=crop',
            price: 3290,
            quantity: 1,
          ),
        ],
        total: 3365,
        buyerName: 'LIKHAE Buyer',
        buyerContact: '0917 123 4567',
        shippingAddress: '1 aaasasa, Masico, Pila, Laguna, 4010',
        timeline: const <BuyerOrderTimelineEvent>[
          BuyerOrderTimelineEvent(
            label: 'Order Placed',
            time: 'Sep 20, 2026 · 10:05 AM',
            done: true,
          ),
          BuyerOrderTimelineEvent(
            label: 'Delivered',
            time: 'Sep 22, 2026 · 2:40 PM',
            done: true,
          ),
        ],
        createdAt: DateTime(2026, 9, 20, 10, 5),
        isPreview: true,
        allowCancel: false,
        allowMarkReceived: false,
        allowReview: false,
        allowReturnRequest: false,
      ),
    ];
  }

  static String _sampleDateTime(DateTime value) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final int hour12 = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;

    final String minute = value.minute.toString().padLeft(2, '0');

    final String period = value.hour >= 12 ? 'PM' : 'AM';

    return '${months[value.month - 1]} ${value.day}, ${value.year} · $hour12:$minute $period';
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _returnDetailsController.dispose();

    super.dispose();
  }

  BuyerOrderData? get _selectedOrder {
    final String? id = _selectedOrderId;

    if (id == null) {
      return null;
    }

    for (final BuyerOrderData order in _orders) {
      if (order.id == id) {
        return order;
      }
    }

    return null;
  }

  BuyerOrderProductData? get _selectedReviewProduct {
    final BuyerOrderData? order = _selectedOrder;

    final String? productId = _selectedReviewProductId;

    if (order == null || productId == null) {
      return null;
    }

    for (final BuyerOrderProductData product in order.products) {
      if (product.id == productId) {
        return product;
      }
    }

    return null;
  }

  List<BuyerOrderData> get _visibleOrders {
    if (_activeTab == BuyerOrderTab.all) {
      return _orders;
    }

    return _orders
        .where(
          (BuyerOrderData order) => order.tabStatus == _activeTab.statusKey,
        )
        .toList();
  }

  int _tabCount(BuyerOrderTab tab) {
    if (tab == BuyerOrderTab.all) {
      return _orders.length;
    }

    return _orders
        .where((BuyerOrderData order) => order.tabStatus == tab.statusKey)
        .length;
  }

  void _syncSelectedReviewProduct() {
    final BuyerOrderData? order = _selectedOrder;

    if (order == null || order.products.isEmpty) {
      _selectedReviewProductId = null;
      return;
    }

    final bool stillExists = order.products.any(
      (BuyerOrderProductData product) => product.id == _selectedReviewProductId,
    );

    if (!stillExists) {
      _selectedReviewProductId = order.products.first.id;
    }
  }

  void _openIndex() {
    FocusScope.of(context).unfocus();

    setState(() {
      _mode = BuyerOrdersMode.overview;

      _selectedOrderId = null;

      _selectedReviewProductId = null;
    });
  }

  void _openDetails(BuyerOrderData order) {
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedOrderId = order.id;

      _mode = BuyerOrdersMode.details;
    });
  }

  void _openReview(BuyerOrderData order) {
    if (!order.canReview) {
      _showMessage('This order is not ready for review yet.', error: true);

      return;
    }

    if (order.products.isEmpty) {
      _showMessage('No product is available to review.', error: true);

      return;
    }

    _reviewController.clear();

    setState(() {
      _selectedOrderId = order.id;

      _selectedReviewProductId = order.products.first.id;

      _rating = 5;

      _mode = BuyerOrdersMode.review;
    });
  }

  void _openReturn(BuyerOrderData order) {
    if (!order.canRequestReturn) {
      _showMessage(
        'This order is not currently eligible for a return or refund request.',
        error: true,
      );

      return;
    }

    _returnDetailsController.clear();

    setState(() {
      _selectedOrderId = order.id;

      _returnRequestType = null;

      _returnReason = null;

      _mode = BuyerOrdersMode.returnRequest;
    });
  }

  Future<void> _refresh() async {
    final OrdersRefreshCallback? callback = widget.onRefresh;

    if (callback == null) {
      return;
    }

    try {
      await callback();
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    }
  }

  Future<void> _markReceived(BuyerOrderData order) async {
    if (_receivingOrder) {
      return;
    }

    if (!order.canMarkReceived) {
      _showMessage(
        'You can confirm receipt only after the order is marked delivered.',
        error: true,
      );

      return;
    }

    final ReceiveOrderCallback? callback = widget.onReceiveOrder;

    if (callback == null) {
      _showMessage('Order receipt will be connected to Laravel later.');

      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Confirm receipt?',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Confirm only after the parcel has actually been delivered to you.',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Not Yet'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _maroon,
                foregroundColor: Colors.white,
              ),
              child: const Text('Order Received'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _receivingOrder = true;
    });

    try {
      await callback(order);

      if (!mounted) {
        return;
      }

      final int index = _orders.indexWhere(
        (BuyerOrderData current) => current.id == order.id,
      );

      if (index >= 0) {
        setState(() {
          _orders[index] = order.copyWith(
            status: 'completed',
            backendStatus: 'completed',
            statusLabel: 'Completed',
            allowMarkReceived: false,
            allowReview: true,
          );
        });
      }

      _showMessage('Order marked as received.');
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _receivingOrder = false;
        });
      }
    }
  }

  Future<void> _showCancelDialog(BuyerOrderData order) async {
    if (!order.canCancel) {
      _showMessage('This order can no longer be cancelled.', error: true);

      return;
    }

    final TextEditingController noteController = TextEditingController();

    String? selectedReason;

    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            Future<void> submitCancellation() async {
              final String? reason = selectedReason;

              if (reason == null || reason.trim().isEmpty) {
                return;
              }

              final CancelOrderCallback? callback = widget.onCancelOrder;

              if (callback == null) {
                Navigator.of(sheetContext).pop();

                _showMessage(
                  'Order cancellation will be connected to Laravel later.',
                );

                return;
              }

              setSheetState(() {
                submitting = true;
              });

              try {
                await callback(order, reason, noteController.text.trim());

                if (!mounted) {
                  return;
                }

                final int index = _orders.indexWhere(
                  (BuyerOrderData current) => current.id == order.id,
                );

                if (index >= 0) {
                  setState(() {
                    _orders[index] = order.copyWith(
                      status: 'cancelled',
                      backendStatus: 'cancelled',
                      statusLabel: 'Cancelled',
                      allowCancel: false,
                      allowMarkReceived: false,
                      allowReview: false,
                      allowReturnRequest: false,
                    );
                  });
                }

                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }

                _showMessage('Order cancelled.');
              } catch (error) {
                _showMessage(_errorText(error), error: true);

                if (sheetContext.mounted) {
                  setSheetState(() {
                    submitting = false;
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
                  decoration: const BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _border,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        const Text(
                          'CANCELLATION',
                          style: TextStyle(
                            color: _maroon,
                            fontSize: 11,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 7),

                        const Text(
                          'If Laravel no longer allows cancellation when this request reaches the server, the order will remain active.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 18),

                        const _InputLabel(text: 'Reason'),

                        const SizedBox(height: 7),

                        DropdownButtonFormField<String>(
                          initialValue: selectedReason,
                          isExpanded: true,
                          decoration: _sheetInputDecoration(
                            hintText: 'Choose a reason',
                          ),
                          items: _cancelReasons.map((String reason) {
                            return DropdownMenuItem<String>(
                              value: reason,
                              child: Text(reason),
                            );
                          }).toList(),
                          onChanged: submitting
                              ? null
                              : (String? value) {
                                  setSheetState(() {
                                    selectedReason = value;
                                  });
                                },
                        ),

                        const SizedBox(height: 15),

                        const _InputLabel(
                          text: 'Additional note',
                          requiredField: false,
                        ),

                        const SizedBox(height: 7),

                        TextField(
                          controller: noteController,
                          enabled: !submitting,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _sheetInputDecoration(
                            hintText: 'Optional note',
                          ),
                        ),

                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: submitting
                                    ? null
                                    : () {
                                        Navigator.of(sheetContext).pop();
                                      },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _maroon,
                                  side: const BorderSide(color: _tan),
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                child: const Text('Keep Order'),
                              ),
                            ),

                            const SizedBox(width: 9),

                            Expanded(
                              child: ElevatedButton(
                                onPressed: submitting || selectedReason == null
                                    ? null
                                    : submitCancellation,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: _danger,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                child: submitting
                                    ? const SizedBox(
                                        width: 19,
                                        height: 19,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Cancel Order'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
  }

  Future<void> _submitReview() async {
    final BuyerOrderData? order = _selectedOrder;

    final BuyerOrderProductData? product = _selectedReviewProduct;

    if (order == null || product == null) {
      return;
    }

    if (!order.canReview) {
      _showMessage('This order is not ready for review.', error: true);

      return;
    }

    if (!(_reviewFormKey.currentState?.validate() ?? false)) {
      return;
    }

    if (widget.onSubmitProductReview == null && widget.onSubmitReview == null) {
      _showMessage(
        'Product review submission will be connected to Laravel later.',
      );

      return;
    }

    setState(() {
      _submittingReview = true;
    });

    try {
      if (widget.onSubmitProductReview != null) {
        await widget.onSubmitProductReview!(
          BuyerOrderReviewRequest(
            order: order,
            product: product,
            rating: _rating,
            review: _reviewController.text.trim(),
          ),
        );
      } else {
        await widget.onSubmitReview!(
          order,
          _rating,
          _reviewController.text.trim(),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _reviewedProductIds.add(product.id);

        _reviewController.clear();
      });

      _showMessage('Review submitted for ${product.name}.');

      if (order.products.length > 1) {
        final BuyerOrderProductData? nextProduct = order.products
            .cast<BuyerOrderProductData?>()
            .firstWhere(
              (BuyerOrderProductData? candidate) =>
                  candidate != null &&
                  !_reviewedProductIds.contains(candidate.id),
              orElse: () => null,
            );

        if (nextProduct != null) {
          setState(() {
            _selectedReviewProductId = nextProduct.id;

            _rating = 5;
          });

          return;
        }
      }

      _openDetails(order);
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _submittingReview = false;
        });
      }
    }
  }

  Future<void> _submitReturn() async {
    final BuyerOrderData? order = _selectedOrder;

    if (order == null) {
      return;
    }

    if (!order.canRequestReturn) {
      _showMessage(
        'This order is not currently eligible for a return or refund request.',
        error: true,
      );

      return;
    }

    if (!(_returnFormKey.currentState?.validate() ?? false)) {
      return;
    }

    final String? requestType = _returnRequestType;

    final String? reason = _returnReason;

    if (requestType == null || reason == null) {
      return;
    }

    if (widget.onSubmitReturnRequest == null && widget.onSubmitReturn == null) {
      _showMessage(
        'Return / refund submission will be connected to Laravel later.',
      );

      return;
    }

    setState(() {
      _submittingReturn = true;
    });

    try {
      final String details = _returnDetailsController.text.trim();

      if (widget.onSubmitReturnRequest != null) {
        await widget.onSubmitReturnRequest!(
          BuyerOrderReturnRequest(
            order: order,
            requestType: requestType,
            reason: reason,
            details: details,
          ),
        );
      } else {
        await widget.onSubmitReturn!(order, requestType, reason, details);
      }

      if (!mounted) {
        return;
      }

      final int index = _orders.indexWhere(
        (BuyerOrderData current) => current.id == order.id,
      );

      if (index >= 0) {
        setState(() {
          _orders[index] = order.copyWith(
            status: 'returns',
            backendStatus: 'returns',
            statusLabel: 'Return / Refund Requested',
            allowCancel: false,
            allowMarkReceived: false,
            allowReview: false,
            allowReturnRequest: false,
          );
        });
      }

      _showMessage('Return / refund request submitted.');

      final BuyerOrderData updatedOrder = index >= 0
          ? _orders[index]
          : order.copyWith(
              status: 'returns',
              backendStatus: 'returns',
              statusLabel: 'Return / Refund Requested',
              allowCancel: false,
              allowMarkReceived: false,
              allowReview: false,
              allowReturnRequest: false,
            );

      _openDetails(updatedOrder);
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _submittingReturn = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? _danger : _maroonDark,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
  }

  String _errorText(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: RefreshIndicator(
                color: _maroon,
                onRefresh: _refresh,
                child: _buildCurrentMode(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentMode() {
    switch (_mode) {
      case BuyerOrdersMode.success:
        return _buildSuccessMode();

      case BuyerOrdersMode.details:
        return _buildDetailsMode();

      case BuyerOrdersMode.review:
        return _buildReviewMode();

      case BuyerOrdersMode.returnRequest:
        return _buildReturnMode();

      case BuyerOrdersMode.overview:
        return _buildOrdersIndex();
    }
  }

  Widget _buildTopBar() {
    final bool innerPage =
        _mode != BuyerOrdersMode.overview && _mode != BuyerOrdersMode.success;

    return Container(
      padding: const EdgeInsets.fromLTRB(7, 5, 12, 7),
      decoration: const BoxDecoration(
        color: _background,
        border: Border(bottom: BorderSide(color: Color(0xFFF0E8DF))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () {
              if (innerPage) {
                _openIndex();
                return;
              }

              if (widget.onBack != null) {
                widget.onBack!();
                return;
              }

              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.arrow_back_rounded, color: _text),
          ),

          const SizedBox(width: 2),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _modeTitle,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  _modeSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11.5),
                ),
              ],
            ),
          ),

          if (_mode == BuyerOrdersMode.overview)
            TextButton(
              onPressed: widget.onShopProducts,
              child: const Text(
                'Shop',
                style: TextStyle(
                  color: _maroon,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String get _modeTitle {
    switch (_mode) {
      case BuyerOrdersMode.overview:
        return 'My Orders';

      case BuyerOrdersMode.success:
        return 'Order Placed';

      case BuyerOrdersMode.details:
        return 'Order Details';

      case BuyerOrdersMode.review:
        return 'Review Product';

      case BuyerOrdersMode.returnRequest:
        return 'Return / Refund';
    }
  }

  String get _modeSubtitle {
    switch (_mode) {
      case BuyerOrdersMode.overview:
        return 'Track, receive, review, or request a return';

      case BuyerOrdersMode.success:
        return 'Your order was submitted successfully';

      case BuyerOrdersMode.details:
        return 'Order and shipment information';

      case BuyerOrdersMode.review:
        return 'Review a completed product';

      case BuyerOrdersMode.returnRequest:
        return 'Submit a return or refund request';
    }
  }

  Widget _buildOrdersIndex() {
    final List<BuyerOrderData> visibleOrders = _visibleOrders;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                if (widget.buyerNotice != null) ...[
                  _NoticeCard(message: widget.buyerNotice!),

                  const SizedBox(height: 14),
                ],

                if (_usingProductPreview) ...[
                  const _NoticeCard(
                    message:
                        'Sample order preview only — tap View Details to inspect the complete order screen. These cards are not saved to Laravel and real database orders automatically replace them once provided.',
                  ),

                  const SizedBox(height: 14),
                ],

                _buildOrdersHeading(),

                const SizedBox(height: 16),

                _buildTabs(),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        if (visibleOrders.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _buildEmptyOrders())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((
                BuildContext context,
                int index,
              ) {
                final BuyerOrderData order = visibleOrders[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: _OrderCard(
                    order: order,
                    onOpen: () {
                      _openDetails(order);
                    },
                    onTrack: widget.onTrackOrder == null
                        ? null
                        : () {
                            widget.onTrackOrder!(order);
                          },
                    onCancel: order.canCancel
                        ? () {
                            _showCancelDialog(order);
                          }
                        : null,
                    onReceive: order.canMarkReceived
                        ? () {
                            _markReceived(order);
                          }
                        : null,
                    onReview: order.canReview
                        ? () {
                            _openReview(order);
                          }
                        : null,
                    onReturn: order.canRequestReturn
                        ? () {
                            _openReturn(order);
                          }
                        : null,
                    receiving: _receivingOrder,
                  ),
                );
              }, childCount: visibleOrders.length),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }

  Widget _buildOrdersHeading() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ORDER CENTER',
                style: TextStyle(
                  color: _maroon,
                  fontSize: 11,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.w900,
                ),
              ),

              SizedBox(height: 5),

              Text(
                'My Orders',
                style: TextStyle(
                  color: _text,
                  fontSize: 28,
                  letterSpacing: -0.7,
                  fontWeight: FontWeight.w900,
                ),
              ),

              SizedBox(height: 6),

              Text(
                'Payment, seller preparation, delivery, receipt, reviews, and return cases in one place.',
                style: TextStyle(color: _muted, fontSize: 12.5, height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        Text(
          '${_orders.length} ${_orders.length == 1 ? 'order' : 'orders'}',
          style: const TextStyle(
            color: _maroon,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return SizedBox(
      height: 45,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: BuyerOrderTab.values.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int index) {
          final BuyerOrderTab tab = BuyerOrderTab.values[index];

          final bool selected = tab == _activeTab;

          return Material(
            color: selected ? _maroon : _surface,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeTab = tab;
                });
              },
              borderRadius: BorderRadius.circular(11),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  border: Border.all(color: selected ? _maroon : _border),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: selected ? Colors.white : _text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(width: 5),

                    Text(
                      '${_tabCount(tab)}',
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.75)
                            : _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFFF1E4D7),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.receipt_long_outlined,
                color: _maroon,
                size: 31,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'No orders in this section',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _text,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'Orders matching this status will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12.5),
            ),

            const SizedBox(height: 19),

            OutlinedButton.icon(
              onPressed: widget.onShopProducts,
              style: OutlinedButton.styleFrom(
                foregroundColor: _maroon,
                side: const BorderSide(color: _tan),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.storefront_outlined, size: 17),
              label: const Text('Shop Products'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessMode() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(18),
      children: [
        const SizedBox(height: 45),

        Center(
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFF1E4D7),
              borderRadius: BorderRadius.circular(21),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check_rounded, size: 38, color: _maroon),
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'ORDER PLACED',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _maroon,
            fontSize: 11,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'Thank you for your order',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _text,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 9),

        const Text(
          'Your order was submitted successfully. Open My Orders to follow its current payment, preparation, shipment, and delivery status.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 13, height: 1.55),
        ),

        const SizedBox(height: 24),

        SizedBox(
          height: 49,
          child: ElevatedButton(
            onPressed: _openIndex,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: _maroon,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text(
              'View My Orders',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),

        const SizedBox(height: 9),

        SizedBox(
          height: 49,
          child: OutlinedButton(
            onPressed: widget.onShopProducts,
            style: OutlinedButton.styleFrom(
              foregroundColor: _maroon,
              side: const BorderSide(color: _tan),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text('Continue Shopping'),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsMode() {
    final BuyerOrderData? order = _selectedOrder;

    if (order == null) {
      return _buildOrderNotFound();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
      children: [
        const Text(
          'ORDER DETAILS',
          style: TextStyle(
            color: _maroon,
            fontSize: 11,
            letterSpacing: 1.7,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          '#${order.id}',
          style: const TextStyle(
            color: _text,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          '${order.statusLabel} · ${order.payment}',
          style: const TextStyle(color: _muted, fontSize: 12.5),
        ),

        const SizedBox(height: 16),

        if (order.isPreview) ...[
          const _NoticeCard(
            message:
                'Sample order details only. This is a UI preview and is not stored in Laravel.',
          ),

          const SizedBox(height: 14),
        ],

        _OrderCard(
          order: order,
          onOpen: null,
          onTrack: widget.onTrackOrder == null
              ? null
              : () {
                  widget.onTrackOrder!(order);
                },
          onCancel: order.canCancel
              ? () {
                  _showCancelDialog(order);
                }
              : null,
          onReceive: order.canMarkReceived
              ? () {
                  _markReceived(order);
                }
              : null,
          onReview: order.canReview
              ? () {
                  _openReview(order);
                }
              : null,
          onReturn: order.canRequestReturn
              ? () {
                  _openReturn(order);
                }
              : null,
          receiving: _receivingOrder,
          showDetailsButton: false,
        ),

        const SizedBox(height: 14),

        _buildShipmentTimeline(order),

        const SizedBox(height: 14),

        _buildDeliveryDetails(order),

        const SizedBox(height: 14),

        _buildPaymentSummary(order),
      ],
    );
  }

  Widget _buildShipmentTimeline(BuyerOrderData order) {
    return _OrderSection(
      title: 'Shipment Timeline',
      icon: Icons.local_shipping_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.timeline.isEmpty)
            const Text(
              'No shipment events recorded yet.',
              style: TextStyle(color: _muted, fontSize: 12.5),
            )
          else
            ...List<Widget>.generate(order.timeline.length, (int index) {
              final BuyerOrderTimelineEvent event = order.timeline[index];

              return _TimelineItem(
                event: event,
                showLine: index != order.timeline.length - 1,
              );
            }),

          if (widget.onTrackOrder != null) ...[
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () {
                widget.onTrackOrder!(order);
              },
              icon: const Icon(Icons.location_searching_rounded, size: 16),
              label: const Text('Track Order'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _maroon,
                side: const BorderSide(color: _tan),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryDetails(BuyerOrderData order) {
    return _OrderSection(
      title: 'Delivery Details',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.buyerName,
            style: const TextStyle(
              color: _text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),

          if (order.buyerContact?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),

            Text(
              order.buyerContact!,
              style: const TextStyle(color: _muted, fontSize: 11.5),
            ),
          ],

          const SizedBox(height: 8),

          Text(
            order.shippingAddress.trim().isEmpty
                ? 'No delivery address recorded.'
                : order.shippingAddress,
            style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.5),
          ),

          if (order.tracking?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_rounded, color: _maroon, size: 18),

                  const SizedBox(width: 8),

                  const Text(
                    'Tracking',
                    style: TextStyle(color: _muted, fontSize: 11.5),
                  ),

                  const Spacer(),

                  Flexible(
                    child: Text(
                      order.tracking!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentSummary(BuyerOrderData order) {
    return _OrderSection(
      title: 'Payment Summary',
      icon: Icons.payment_outlined,
      child: Column(
        children: [
          _DetailRow(label: 'Order total', value: _formatPrice(order.total)),

          const SizedBox(height: 11),

          const Divider(height: 1, color: _border),

          const SizedBox(height: 11),

          _DetailRow(
            label: 'Order status',
            value: order.statusLabel,
            valueColor: _maroon,
          ),

          const SizedBox(height: 11),

          _DetailRow(label: 'Payment method', value: order.payment),

          if (order.paymentStatus?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 11),

            _DetailRow(label: 'Payment status', value: order.paymentStatus!),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewMode() {
    final BuyerOrderData? order = _selectedOrder;

    if (order == null) {
      return _buildOrderNotFound();
    }

    final BuyerOrderProductData? product = _selectedReviewProduct;

    if (product == null) {
      return _buildOrderNotFound();
    }

    return Form(
      key: _reviewFormKey,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
        children: [
          Text(
            'ORDER #${order.id}',
            style: const TextStyle(
              color: _maroon,
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Review Product',
            style: TextStyle(
              color: _text,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Choose a product from this completed order and share your experience.',
            style: TextStyle(color: _muted, fontSize: 12.5),
          ),

          const SizedBox(height: 17),

          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.products.length > 1) ...[
                  const _InputLabel(text: 'Product'),

                  const SizedBox(height: 7),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedReviewProductId,
                    isExpanded: true,
                    decoration: _inputDecoration(hintText: 'Choose product'),
                    items: order.products.map((BuyerOrderProductData item) {
                      final bool reviewed = _reviewedProductIds.contains(
                        item.id,
                      );

                      return DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(
                          reviewed ? '${item.name} — Reviewed' : item.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _submittingReview
                        ? null
                        : (String? value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _selectedReviewProductId = value;

                              _reviewController.clear();

                              _rating = 5;
                            });
                          },
                  ),

                  const SizedBox(height: 16),
                ],

                _SelectedProduct(product: product),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: _border),
                ),

                const _InputLabel(text: 'Your rating'),

                const SizedBox(height: 9),

                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: List<Widget>.generate(5, (int index) {
                    final int starValue = index + 1;

                    final bool selected = _rating >= starValue;

                    return InkWell(
                      onTap: _submittingReview
                          ? null
                          : () {
                              setState(() {
                                _rating = starValue;
                              });
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          selected
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: _star,
                          size: 31,
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 8),

                Text(
                  '$_rating out of 5',
                  style: const TextStyle(color: _muted, fontSize: 11.5),
                ),

                const SizedBox(height: 18),

                const _InputLabel(text: 'Review'),

                const SizedBox(height: 7),

                TextFormField(
                  controller: _reviewController,
                  enabled: !_submittingReview,
                  minLines: 5,
                  maxLines: 7,
                  maxLength: 3000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    hintText: 'Quality, fit, packaging, and your experience...',
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Write your review.';
                    }

                    if (value.trim().length > 3000) {
                      return 'Review must not exceed 3000 characters.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 17),

                SizedBox(
                  width: double.infinity,
                  height: 49,
                  child: ElevatedButton(
                    onPressed: _submittingReview ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _maroon,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: _submittingReview
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Review',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnMode() {
    final BuyerOrderData? order = _selectedOrder;

    if (order == null) {
      return _buildOrderNotFound();
    }

    return Form(
      key: _returnFormKey,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
        children: [
          Text(
            'ORDER #${order.id}',
            style: const TextStyle(
              color: _maroon,
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Return / Refund Request',
            style: TextStyle(
              color: _text,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Provide the request type, reason, and details for review.',
            style: TextStyle(color: _muted, fontSize: 12.5),
          ),

          const SizedBox(height: 17),

          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.products.isNotEmpty)
                  _SelectedProduct(product: order.products.first),

                if (order.products.length > 1) ...[
                  const SizedBox(height: 7),

                  Text(
                    '+${order.products.length - 1} additional ${order.products.length - 1 == 1 ? 'product' : 'products'} in this order',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],

                if (order.products.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: _border),
                  ),

                const _InputLabel(text: 'Request type'),

                const SizedBox(height: 7),

                DropdownButtonFormField<String>(
                  initialValue: _returnRequestType,
                  isExpanded: true,
                  decoration: _inputDecoration(hintText: 'Choose an option'),
                  items: _returnTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: _submittingReturn
                      ? null
                      : (String? value) {
                          setState(() {
                            _returnRequestType = value;
                          });
                        },
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Choose a request type.';
                    }

                    if (value.length > 80) {
                      return 'Request type is too long.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                const _InputLabel(text: 'Reason'),

                const SizedBox(height: 7),

                DropdownButtonFormField<String>(
                  initialValue: _returnReason,
                  isExpanded: true,
                  decoration: _inputDecoration(hintText: 'Choose a reason'),
                  items: _returnReasons.map((String reason) {
                    return DropdownMenuItem<String>(
                      value: reason,
                      child: Text(reason),
                    );
                  }).toList(),
                  onChanged: _submittingReturn
                      ? null
                      : (String? value) {
                          setState(() {
                            _returnReason = value;
                          });
                        },
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Choose a reason.';
                    }

                    if (value.length > 255) {
                      return 'Reason must not exceed 255 characters.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                const _InputLabel(text: 'Explain what happened'),

                const SizedBox(height: 7),

                TextFormField(
                  controller: _returnDetailsController,
                  enabled: !_submittingReturn,
                  minLines: 5,
                  maxLines: 7,
                  maxLength: 3000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    hintText: 'Give enough detail to review this request.',
                  ),
                  validator: (String? value) {
                    final String text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'Explain what happened.';
                    }

                    if (text.length < 20) {
                      return 'Please provide at least 20 characters.';
                    }

                    if (text.length > 3000) {
                      return 'Details must not exceed 3000 characters.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 15),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Submitting this form creates a request for review. It does not automatically mean the refund or return has been approved.',
                    style: TextStyle(
                      color: Color(0xFF7A5115),
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 17),

                SizedBox(
                  width: double.infinity,
                  height: 49,
                  child: ElevatedButton(
                    onPressed: _submittingReturn ? null : _submitReturn,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _maroon,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: _submittingReturn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Request',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderNotFound() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 80),

        const Icon(Icons.search_off_rounded, size: 58, color: _muted2),

        const SizedBox(height: 15),

        const Text(
          'Order not found',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _text,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'This order is unavailable or does not belong to your account.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12.5),
        ),

        const SizedBox(height: 18),

        Center(
          child: OutlinedButton(
            onPressed: _openIndex,
            child: const Text('Back to Orders'),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: _muted2, fontSize: 12.5),
      filled: true,
      fillColor: _soft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _maroon, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _danger, width: 1.3),
      ),
    );
  }

  InputDecoration _sheetInputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: _muted2, fontSize: 12.5),
      filled: true,
      fillColor: _soft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _maroon),
      ),
    );
  }

  static String _formatPrice(double value) {
    return '₱${value.toStringAsFixed(2)}';
  }
}

class _OrderCard extends StatelessWidget {
  final BuyerOrderData order;

  final VoidCallback? onOpen;
  final VoidCallback? onTrack;
  final VoidCallback? onCancel;
  final VoidCallback? onReceive;
  final VoidCallback? onReview;
  final VoidCallback? onReturn;

  final bool receiving;

  final bool showDetailsButton;

  const _OrderCard({
    required this.order,
    required this.onOpen,
    required this.onTrack,
    required this.onCancel,
    required this.onReceive,
    required this.onReview,
    required this.onReturn,
    required this.receiving,
    this.showDetailsButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        border: Border.all(color: const Color(0xFFEADCCC)),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            decoration: const BoxDecoration(color: Color(0xFFF9F2EA)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 3,
                    children: [
                      Text(
                        'Order #${order.id}',
                        style: const TextStyle(
                          color: Color(0xFF3B211B),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        _placedLabel(order.createdAt),
                        style: const TextStyle(
                          color: Color(0xFF987865),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                _StatusBadge(label: order.statusLabel, status: order.tabStatus),
              ],
            ),
          ),

          if (order.products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No products recorded for this order.',
                  style: TextStyle(color: Color(0xFF987865), fontSize: 12.5),
                ),
              ),
            )
          else
            Column(
              children: List<Widget>.generate(order.products.length, (
                int index,
              ) {
                return _OrderProductRow(
                  product: order.products[index],
                  showDivider: index != order.products.length - 1,
                );
              }, growable: false),
            ),

          const Divider(height: 1, color: Color(0xFFF0E8DF)),

          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: order.payment),
                            const TextSpan(text: ' · '),
                            TextSpan(
                              text: _price(order.total),
                              style: const TextStyle(
                                color: Color(0xFF3B211B),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          color: Color(0xFF987865),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),

                if (showDetailsButton ||
                    onTrack != null ||
                    onCancel != null ||
                    onReceive != null ||
                    onReview != null ||
                    onReturn != null) ...[
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        if (onCancel != null)
                          _SmallActionButton(
                            text: 'Cancel',
                            onPressed: onCancel,
                            danger: true,
                          ),

                        if (onReturn != null)
                          _SmallActionButton(
                            text: 'Return / Refund',
                            onPressed: onReturn,
                          ),

                        if (onReview != null)
                          _SmallActionButton(
                            text: 'Review',
                            onPressed: onReview,
                          ),

                        if (onReceive != null)
                          _SmallActionButton(
                            text: receiving ? 'Updating...' : 'Order Received',
                            onPressed: receiving ? null : onReceive,
                            filled: true,
                          ),

                        if (onTrack != null &&
                            order.tracking?.trim().isNotEmpty == true)
                          _SmallActionButton(
                            text: 'Track Parcel',
                            onPressed: onTrack,
                          ),

                        if (showDetailsButton && onOpen != null)
                          _SmallActionButton(
                            text: 'View Details',
                            onPressed: onOpen,
                            filled: false,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _placedLabel(DateTime? value) {
    if (value == null) {
      return '';
    }

    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final DateTime local = value.toLocal();

    final int hour12 = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;

    final String minute = local.minute.toString().padLeft(2, '0');

    final String period = local.hour >= 12 ? 'PM' : 'AM';

    return 'Placed ${months[local.month - 1]} ${local.day}, ${local.year}, $hour12:$minute $period';
  }

  static String _price(double value) {
    return '₱${value.toStringAsFixed(2)}';
  }
}

class _OrderProductRow extends StatelessWidget {
  final BuyerOrderProductData product;
  final bool showDivider;

  const _OrderProductRow({required this.product, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3ECE4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEADCCC)),
                ),
                child: _OrderProductImage(imageUrl: product.imageUrl),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF3B211B),
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    if (product.variant?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.variant!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF987865),
                          fontSize: 11.5,
                        ),
                      ),
                    ],

                    const SizedBox(height: 5),

                    Text(
                      'Qty ${product.safeQuantity}',
                      style: const TextStyle(
                        color: Color(0xFFA99386),
                        fontSize: 11.5,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      '₱${product.lineTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF561C17),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (showDivider) const Divider(height: 1, color: Color(0xFFF0E8DF)),
      ],
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final String text;

  final VoidCallback? onPressed;

  final bool filled;
  final bool danger;

  const _SmallActionButton({
    required this.text,
    required this.onPressed,
    this.filled = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        height: 38,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF561C17),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: danger
              ? const Color(0xFFB42318)
              : const Color(0xFF561C17),
          side: BorderSide(
            color: danger ? const Color(0xFFE5B4A9) : const Color(0xFFC19771),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final String status;

  const _StatusBadge({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;

    switch (status) {
      case 'completed':
        background = const Color(0xFFEAF6EE);

        foreground = const Color(0xFF237A44);

        break;

      case 'cancelled':
        background = const Color(0xFFFCEBE8);

        foreground = const Color(0xFFB42318);

        break;

      case 'returns':
        background = const Color(0xFFFFF3DC);

        foreground = const Color(0xFF906010);

        break;

      case 'to-receive':
        background = const Color(0xFFEAF1FF);

        foreground = const Color(0xFF315B9A);

        break;

      default:
        background = const Color(0xFFF1E4D7);

        foreground = const Color(0xFF561C17);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _OrderSection extends StatelessWidget {
  final String title;

  final IconData icon;

  final Widget child;

  const _OrderSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        border: Border.all(color: const Color(0xFFEADCCC)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 37,
                height: 37,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1E4D7),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: const Color(0xFF561C17), size: 18),
              ),

              const SizedBox(width: 9),

              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF3B211B),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          child,
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final BuyerOrderTimelineEvent event;

  final bool showLine;

  const _TimelineItem({required this.event, required this.showLine});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: event.done
                        ? const Color(0xFF561C17)
                        : const Color(0xFFF1ECE7),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    event.done ? Icons.check_rounded : Icons.circle,
                    color: event.done ? Colors.white : const Color(0xFFA99386),
                    size: event.done ? 15 : 6,
                  ),
                ),

                if (showLine)
                  Expanded(
                    child: Container(width: 1, color: const Color(0xFFEADCCC)),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.label,
                    style: const TextStyle(
                      color: Color(0xFF3B211B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    event.time.trim().isEmpty ? 'Pending' : event.time,
                    style: const TextStyle(
                      color: Color(0xFFA99386),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedProduct extends StatelessWidget {
  final BuyerOrderProductData product;

  const _SelectedProduct({required this.product});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF3ECE4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _OrderProductImage(imageUrl: product.imageUrl),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  color: Color(0xFF3B211B),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),

              if (product.variant?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 4),

                Text(
                  product.variant!,
                  style: const TextStyle(
                    color: Color(0xFF987865),
                    fontSize: 11,
                  ),
                ),
              ],

              const SizedBox(height: 4),

              Text(
                'Qty ${product.safeQuantity}',
                style: const TextStyle(color: Color(0xFFA99386), fontSize: 11),
              ),
            ],
          ),
        ),

        Text(
          '₱${product.lineTotal.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Color(0xFF561C17),
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _OrderProductImage extends StatelessWidget {
  final String? imageUrl;

  const _OrderProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl?.trim();

    if (url == null || url.isEmpty) {
      return const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFFA99386), size: 28),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder:
          (BuildContext context, Widget child, ImageChunkEvent? progress) {
            if (progress == null) {
              return child;
            }

            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF561C17),
                ),
              ),
            );
          },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Color(0xFFA99386),
                size: 27,
              ),
            );
          },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF987865), fontSize: 12),
          ),
        ),

        const SizedBox(width: 12),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF3B211B),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _InputLabel extends StatelessWidget {
  final String text;

  final bool requiredField;

  const _InputLabel({required this.text, this.requiredField = true});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),

          if (requiredField)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFB42318)),
            ),
        ],
      ),
      style: const TextStyle(
        color: Color(0xFF3B211B),
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String message;

  const _NoticeCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCECE7),
        border: Border.all(color: const Color(0xFFEBC9C0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF561C17),
            size: 18,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF561C17),
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
