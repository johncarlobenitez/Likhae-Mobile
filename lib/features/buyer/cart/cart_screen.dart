import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:likhae/core/config/app_config.dart';

class CartItemData {
  /// Cart item ID.
  ///
  /// Laravel uses this ID when updating/removing a cart row
  /// and when selected cart rows are passed to checkout.
  final String id;

  /// Actual product ID.
  ///
  /// Optional for backward compatibility with the first
  /// Flutter cart implementation.
  final int? productId;

  /// Selected ProductVariation ID when the cart row belongs
  /// to a specific Laravel product variation.
  final int? productVariationId;

  final String? slug;

  final String name;
  final String category;

  /// Human-readable option label such as:
  /// "Cover: Softcover"
  /// "Size: Large"
  /// "Standard"
  final String variant;

  final String seller;
  final int? sellerId;

  final double price;
  final double? oldPrice;

  final int quantity;

  /// Available stock for the selected option.
  final int stock;

  final String? imageUrl;

  const CartItemData({
    required this.id,
    required this.name,
    required this.category,
    required this.variant,
    required this.seller,
    required this.price,
    required this.quantity,
    required this.stock,
    this.productId,
    this.productVariationId,
    this.slug,
    this.sellerId,
    this.oldPrice,
    this.imageUrl,
  });

  double get lineTotal {
    return price * quantity;
  }

  bool get isAvailable {
    return stock > 0;
  }

  CartItemData copyWith({
    int? quantity,
    int? stock,
  }) {
    return CartItemData(
      id: id,
      productId: productId,
      productVariationId: productVariationId,
      slug: slug,
      name: name,
      category: category,
      variant: variant,
      seller: seller,
      sellerId: sellerId,
      price: price,
      oldPrice: oldPrice,
      quantity: quantity ?? this.quantity,
      stock: stock ?? this.stock,
      imageUrl: imageUrl,
    );
  }
}

class DeliveryAddressData {
  final String recipientName;
  final String contactNumber;
  final String formattedAddress;

  final bool isDefault;

  const DeliveryAddressData({
    required this.recipientName,
    required this.contactNumber,
    required this.formattedAddress,
    this.isDefault = true,
  });
}

/// The item snapshot transferred from Cart -> Checkout.
///
/// This deliberately carries the real cart row ID together
/// with product/variation information so Flutter can later
/// build the same checkout selection Laravel expects.
class CartCheckoutItem {
  final String id;

  final int? productId;
  final int? productVariationId;

  final String variant;

  final int quantity;

  const CartCheckoutItem({
    required this.id,
    required this.quantity,
    this.productId,
    this.productVariationId,
    this.variant = 'Standard',
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      if (productId != null)
        'product_id': productId,
      if (productVariationId != null)
        'product_variation_id':
            productVariationId,
      'variant': variant,
      'quantity': quantity,
    };
  }
}

class CartCheckoutRequest {
  /// Always "cart" for this page.
  ///
  /// Buy Now uses a separate direct-checkout flow from
  /// Product Details.
  final String checkoutSource;

  final List<CartCheckoutItem> items;

  const CartCheckoutRequest({
    required this.items,
    this.checkoutSource = 'cart',
  });

  List<Map<String, dynamic>>
      get itemPayload {
    return items
        .map(
          (CartCheckoutItem item) =>
              item.toMap(),
        )
        .toList();
  }
}

typedef CartQuantityUpdateCallback =
    Future<void> Function(
  CartItemData item,
  int quantity,
);

typedef CartRemoveCallback =
    Future<void> Function(
  CartItemData item,
);

typedef CartRemoveSelectedCallback =
    Future<void> Function(
  List<CartItemData> items,
);

typedef CartCheckoutCallback =
    Future<void> Function(
  CartCheckoutRequest request,
);

typedef CartRefreshCallback =
    Future<void> Function();

class CartScreen extends StatefulWidget {
  final List<CartItemData> items;

  final DeliveryAddressData? defaultAddress;

  final VoidCallback? onBack;
  final VoidCallback? onContinueShopping;
  final VoidCallback? onChangeAddress;

  final ValueChanged<CartItemData>?
      onProductSelected;

  final CartQuantityUpdateCallback?
      onUpdateQuantity;

  final CartRemoveCallback?
      onRemoveItem;

  final CartRemoveSelectedCallback?
      onRemoveSelected;

  /// This should navigate to Checkout.
  ///
  /// It should NOT create an order.
  ///
  /// Place Order belongs to checkout_screen.dart.
  final CartCheckoutCallback? onCheckout;

  final CartRefreshCallback? onRefresh;

  const CartScreen({
    super.key,
    this.items = const <CartItemData>[],
    this.defaultAddress,
    this.onBack,
    this.onContinueShopping,
    this.onChangeAddress,
    this.onProductSelected,
    this.onUpdateQuantity,
    this.onRemoveItem,
    this.onRemoveSelected,
    this.onCheckout,
    this.onRefresh,
  });

  @override
  State<CartScreen> createState() =>
      _CartScreenState();
}

class _CartScreenState
    extends State<CartScreen> {
  static const Color _background =
      Color(0xFFFBF7F2);

  static const Color _surface =
      Color(0xFFFFFDF9);

  static const Color _soft =
      Color(0xFFF6EFE7);

  static const Color _border =
      Color(0xFFEADCCC);

  static const Color _maroon =
      Color(0xFF561C17);

  static const Color _maroonDark =
      Color(0xFF3E130F);

  static const Color _text =
      Color(0xFF3B211B);

  static const Color _muted =
      Color(0xFF987865);

  static const Color _brown =
      Color(0xFF6C4936);

  static const Color _danger =
      Color(0xFFB42318);

  late List<CartItemData> _items;

  final Set<String> _selectedIds =
      <String>{};

  final Set<String> _updatingIds =
      <String>{};

  final Set<String> _removingIds =
      <String>{};

  bool _removingSelected = false;
  bool _openingCheckout = false;

  @override
  void initState() {
    super.initState();

    _items =
        List<CartItemData>.from(
      widget.items,
    );

    _selectAllAvailable();
  }

  @override
  void didUpdateWidget(
    covariant CartScreen oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.items !=
        widget.items) {
      final Set<String>
          oldItemIds =
          oldWidget.items
              .map(
                (
                  CartItemData item,
                ) =>
                    item.id,
              )
              .toSet();

      final Set<String>
          previousSelection =
          Set<String>.from(
        _selectedIds,
      );

      _items =
          List<CartItemData>.from(
        widget.items,
      );

      final Set<String>
          currentAvailableIds =
          _availableItems
              .map(
                (
                  CartItemData item,
                ) =>
                    item.id,
              )
              .toSet();

      final Set<String> newIds =
          currentAvailableIds
              .difference(
        oldItemIds,
      );

      _selectedIds
        ..clear()
        ..addAll(
          previousSelection
              .intersection(
            currentAvailableIds,
          ),
        )
        ..addAll(
          newIds,
        );

      if (oldWidget.items.isEmpty &&
          widget.items.isNotEmpty) {
        _selectAllAvailable();
      }
    }
  }

  List<CartItemData>
      get _availableItems {
    return _items
        .where(
          (
            CartItemData item,
          ) =>
              item.isAvailable,
        )
        .toList();
  }

  List<CartItemData>
      get _selectedItems {
    return _items
        .where(
          (
            CartItemData item,
          ) =>
              item.isAvailable &&
              _selectedIds
                  .contains(
                item.id,
              ),
        )
        .toList();
  }

  bool get _allSelected {
    if (_availableItems.isEmpty) {
      return false;
    }

    return _availableItems.every(
      (
        CartItemData item,
      ) =>
          _selectedIds
              .contains(
            item.id,
          ),
    );
  }

  bool get _someSelected {
    return _selectedItems.isNotEmpty &&
        !_allSelected;
  }

  int get _selectedQuantity {
    return _selectedItems.fold<int>(
      0,
      (
        int total,
        CartItemData item,
      ) =>
          total + item.quantity,
    );
  }

  double get _subtotal {
    return _selectedItems
        .fold<double>(
      0,
      (
        double total,
        CartItemData item,
      ) =>
          total + item.lineTotal,
    );
  }

  int get _unavailableCount {
    return _items
        .where(
          (
            CartItemData item,
          ) =>
              !item.isAvailable,
        )
        .length;
  }

  void _selectAllAvailable() {
    _selectedIds
      ..clear()
      ..addAll(
        _items
            .where(
              (
                CartItemData item,
              ) =>
                  item.isAvailable,
            )
            .map(
              (
                CartItemData item,
              ) =>
                  item.id,
            ),
      );
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedIds.clear();
      } else {
        _selectAllAvailable();
      }
    });
  }

  void _toggleItemSelection(
    CartItemData item,
  ) {
    if (!item.isAvailable) {
      _showMessage(
        'This item is currently out of stock.',
        error: true,
      );

      return;
    }

    setState(() {
      if (_selectedIds.contains(
        item.id,
      )) {
        _selectedIds.remove(
          item.id,
        );
      } else {
        _selectedIds.add(
          item.id,
        );
      }
    });
  }

  Future<void> _changeQuantity(
    CartItemData item,
    int requestedQuantity,
  ) async {
    if (!item.isAvailable) {
      _showMessage(
        'This item is currently out of stock.',
        error: true,
      );

      return;
    }

    if (_updatingIds.contains(
      item.id,
    )) {
      return;
    }

    final int quantity =
        math
            .min(
              item.stock,
              math.max(
                1,
                requestedQuantity,
              ),
            )
            .toInt();

    if (quantity ==
        item.quantity) {
      return;
    }

    final CartQuantityUpdateCallback?
        callback =
        widget.onUpdateQuantity;

    if (callback == null) {
      _showMessage(
        'Cart quantity will be connected to Laravel later.',
      );

      return;
    }

    setState(() {
      _updatingIds.add(
        item.id,
      );
    });

    try {
      await callback(
        item,
        quantity,
      );

      if (!mounted) {
        return;
      }

      final int index =
          _items.indexWhere(
        (
          CartItemData current,
        ) =>
            current.id ==
            item.id,
      );

      if (index >= 0) {
        setState(() {
          _items[index] =
              _items[index]
                  .copyWith(
            quantity: quantity,
          );
        });
      }
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingIds.remove(
            item.id,
          );
        });
      }
    }
  }

  Future<void> _removeItem(
    CartItemData item,
  ) async {
    if (_removingIds.contains(
      item.id,
    )) {
      return;
    }

    final bool confirmed =
        await _confirmRemoveSingle(
      item,
    );

    if (!confirmed ||
        !mounted) {
      return;
    }

    final CartRemoveCallback?
        callback =
        widget.onRemoveItem;

    if (callback == null) {
      _showMessage(
        'Cart removal will be connected to Laravel later.',
      );

      return;
    }

    setState(() {
      _removingIds.add(
        item.id,
      );
    });

    try {
      await callback(
        item,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _items.removeWhere(
          (
            CartItemData current,
          ) =>
              current.id ==
              item.id,
        );

        _selectedIds.remove(
          item.id,
        );
      });

      _showMessage(
        '${item.name} removed from cart.',
      );
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _removingIds.remove(
            item.id,
          );
        });
      }
    }
  }

  Future<bool> _confirmRemoveSingle(
    CartItemData item,
  ) async {
    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext context,
      ) {
        return AlertDialog(
          backgroundColor:
              _surface,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),
          title:
              const Text(
            'Remove item?',
            style:
                TextStyle(
              color: _text,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          content: Text(
            'Remove ${item.name} from your cart?',
            style:
                const TextStyle(
              color: _muted,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(
                  false,
                );
              },
              child:
                  const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(
                  true,
                );
              },
              style:
                  ElevatedButton
                      .styleFrom(
                elevation: 0,
                backgroundColor:
                    _danger,
                foregroundColor:
                    Colors.white,
              ),
              child:
                  const Text(
                'Remove',
              ),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _removeSelected() async {
    final List<CartItemData> selected =
        _selectedItems;

    if (selected.isEmpty ||
        _removingSelected) {
      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext context,
      ) {
        return AlertDialog(
          backgroundColor:
              _surface,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),
          title:
              const Text(
            'Remove selected items?',
            style:
                TextStyle(
              color: _text,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          content: Text(
            'Remove ${selected.length} selected ${selected.length == 1 ? 'item' : 'items'} from your cart?',
            style:
                const TextStyle(
              color: _muted,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(
                  false,
                );
              },
              child:
                  const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(
                  true,
                );
              },
              style:
                  ElevatedButton
                      .styleFrom(
                elevation: 0,
                backgroundColor:
                    _danger,
                foregroundColor:
                    Colors.white,
              ),
              child:
                  const Text(
                'Remove',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    if (widget.onRemoveSelected ==
            null &&
        widget.onRemoveItem ==
            null) {
      _showMessage(
        'Cart removal will be connected to Laravel later.',
      );

      return;
    }

    setState(() {
      _removingSelected = true;
    });

    final Set<String>
        successfullyRemoved =
        <String>{};

    try {
      if (widget.onRemoveSelected !=
          null) {
        await widget
            .onRemoveSelected!(
          selected,
        );

        successfullyRemoved.addAll(
          selected.map(
            (
              CartItemData item,
            ) =>
                item.id,
          ),
        );
      } else {
        for (final CartItemData item
            in selected) {
          await widget.onRemoveItem!(
            item,
          );

          successfullyRemoved.add(
            item.id,
          );
        }
      }

      if (!mounted) {
        return;
      }

      _removeIdsLocally(
        successfullyRemoved,
      );

      _showMessage(
        selected.length == 1
            ? 'Selected item removed from cart.'
            : 'Selected items removed from cart.',
      );
    } catch (error) {
      if (mounted &&
          successfullyRemoved
              .isNotEmpty) {
        _removeIdsLocally(
          successfullyRemoved,
        );
      }

      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _removingSelected = false;
        });
      }
    }
  }

  void _removeIdsLocally(
    Set<String> ids,
  ) {
    setState(() {
      _items.removeWhere(
        (
          CartItemData item,
        ) =>
            ids.contains(
          item.id,
        ),
      );

      _selectedIds.removeAll(
        ids,
      );
    });
  }

  Future<void> _openCheckout() async {
    if (_openingCheckout) {
      return;
    }

    final List<CartItemData>
        selected =
        _selectedItems;

    if (selected.isEmpty) {
      _showMessage(
        'Select at least one available cart item before checkout.',
        error: true,
      );

      return;
    }

    final CartCheckoutCallback?
        callback =
        widget.onCheckout;

    if (callback == null) {
      _showMessage(
        'Checkout navigation will be connected later.',
      );

      return;
    }

    final CartCheckoutRequest request =
        CartCheckoutRequest(
      items: selected
          .map(
            (
              CartItemData item,
            ) =>
                CartCheckoutItem(
              id: item.id,
              productId:
                  item.productId,
              productVariationId:
                  item.productVariationId,
              variant:
                  item.variant,
              quantity:
                  item.quantity,
            ),
          )
          .toList(),
    );

    setState(() {
      _openingCheckout = true;
    });

    try {
      /*
       * Important:
       *
       * This does NOT place the order.
       *
       * It only transfers the selected cart rows to
       * CheckoutScreen.
       */
      await callback(
        request,
      );
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingCheckout = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    final CartRefreshCallback? callback =
        widget.onRefresh;

    if (callback == null) {
      return;
    }

    try {
      await callback();
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    }
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              error
                  ? _danger
                  : _maroonDark,
          margin:
              const EdgeInsets.all(
            16,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          content: Text(
            message,
            style:
                const TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
      );
  }

  String _errorText(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child:
                  RefreshIndicator(
                color: _maroon,
                onRefresh:
                    _refresh,
                child:
                    _items.isEmpty
                        ? _buildEmptyCart()
                        : _buildCartContent(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          _items.isEmpty
              ? null
              : _buildBottomCheckoutBar(),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        7,
        5,
        12,
        7,
      ),
      decoration:
          const BoxDecoration(
        color: _background,
        border: Border(
          bottom:
              BorderSide(
            color:
                Color(
              0xFFF0E8DF,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed:
                widget.onBack ??
                () {
                  Navigator.of(
                    context,
                  ).maybePop();
                },
            icon:
                const Icon(
              Icons
                  .arrow_back_rounded,
              color: _text,
            ),
          ),

          const SizedBox(
            width: 2,
          ),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Shopping Cart',
                  style:
                      TextStyle(
                    color: _text,
                    fontSize: 22,
                    height: 1.1,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing:
                        -0.4,
                  ),
                ),

                SizedBox(
                  height: 2,
                ),

                Text(
                  'Select products to continue to checkout',
                  style:
                      TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),

          TextButton(
            onPressed:
                widget
                    .onContinueShopping,
            child:
                const Text(
              'Shop',
              style:
                  TextStyle(
                color: _maroon,
                fontSize: 13.5,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.all(
        24,
      ),
      children: [
        const SizedBox(
          height: 80,
        ),

        Center(
          child: Container(
            width: 82,
            height: 82,
            decoration:
                const BoxDecoration(
              color:
                  Color(
                0xFFF1E4D7,
              ),
              shape:
                  BoxShape.circle,
            ),
            alignment:
                Alignment.center,
            child:
                const Icon(
              Icons
                  .shopping_cart_outlined,
              color: _maroon,
              size: 36,
            ),
          ),
        ),

        const SizedBox(
          height: 22,
        ),

        const Text(
          'Your cart is empty',
          textAlign:
              TextAlign.center,
          style:
              TextStyle(
            color: _text,
            fontSize: 24,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        const Text(
          'Browse the marketplace and add products you would like to purchase.',
          textAlign:
              TextAlign.center,
          style:
              TextStyle(
            color: _muted,
            fontSize: 14,
            height: 1.55,
          ),
        ),

        const SizedBox(
          height: 24,
        ),

        Center(
          child: SizedBox(
            height: 52,
            child:
                ElevatedButton.icon(
              onPressed:
                  widget
                      .onContinueShopping,
              style:
                  ElevatedButton
                      .styleFrom(
                elevation: 0,
                backgroundColor:
                    _maroon,
                foregroundColor:
                    Colors.white,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 20,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    13,
                  ),
                ),
              ),
              icon:
                  const Icon(
                Icons
                    .storefront_outlined,
                size: 18,
              ),
              label:
                  const Text(
                'Browse Products',
                style:
                    TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(
          height: 34,
        ),

        const Text(
          'Items you add will appear here',
          textAlign:
              TextAlign.center,
          style:
              TextStyle(
            color: _text,
            fontSize: 16,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const SizedBox(
          height: 6,
        ),

        const Text(
          'Your selected product image, name, variant, seller, price, quantity, and subtotal will be shown in this section.',
          textAlign:
              TextAlign.center,
          style:
              TextStyle(
            color: _muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),

        const SizedBox(
          height: 18,
        ),

        _buildCartItemPlaceholder(),

        const SizedBox(
          height: 10,
        ),

        _buildCartItemPlaceholder(),
      ],
    );
  }

  Widget _buildCartItemPlaceholder() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color: _surface,
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        border:
            Border.all(
          color: _border,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration:
                BoxDecoration(
              color: _soft,
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
              border:
                  Border.all(
                color: _border,
              ),
            ),
            alignment:
                Alignment.center,
            child:
                const Icon(
              Icons
                  .image_outlined,
              color:
                  _muted,
              size: 32,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  height: 13,
                  width: 92,
                  decoration:
                      BoxDecoration(
                    color:
                        _soft,
                    borderRadius:
                        BorderRadius.circular(
                      100,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Container(
                  height: 16,
                  width:
                      double.infinity,
                  decoration:
                      BoxDecoration(
                    color:
                        _soft,
                    borderRadius:
                        BorderRadius.circular(
                      100,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Container(
                  height: 13,
                  width: 150,
                  decoration:
                      BoxDecoration(
                    color:
                        _soft,
                    borderRadius:
                        BorderRadius.circular(
                      100,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 14,
                ),

                Row(
                  children: [
                    Container(
                      height: 16,
                      width: 82,
                      decoration:
                          BoxDecoration(
                        color:
                            _soft,
                        borderRadius:
                            BorderRadius.circular(
                          100,
                        ),
                      ),
                    ),

                    const Spacer(),

                    Container(
                      height: 32,
                      width: 92,
                      decoration:
                          BoxDecoration(
                        color:
                            _soft,
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                        border:
                            Border.all(
                          color:
                              _border,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent() {
    return CustomScrollView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior
              .onDrag,
      slivers: [
        SliverPadding(
          padding:
              const EdgeInsets.fromLTRB(
            14,
            16,
            14,
            0,
          ),
          sliver:
              SliverToBoxAdapter(
            child: Column(
              children: [
                _buildHeading(),

                const SizedBox(
                  height: 16,
                ),

                _buildSelectionHeader(),

                if (_unavailableCount >
                    0) ...[
                  const SizedBox(
                    height: 10,
                  ),

                  _buildUnavailableNotice(),
                ],

                const SizedBox(
                  height: 10,
                ),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          sliver:
              SliverList(
            delegate:
                SliverChildBuilderDelegate(
              (
                BuildContext context,
                int index,
              ) {
                final CartItemData item =
                    _items[index];

                return Padding(
                  padding:
                      EdgeInsets.only(
                    bottom:
                        index ==
                                _items.length -
                                    1
                            ? 0
                            : 10,
                  ),
                  child:
                      _CartItemCard(
                    item: item,
                    selected:
                        _selectedIds
                            .contains(
                      item.id,
                    ),
                    updating:
                        _updatingIds
                            .contains(
                      item.id,
                    ),
                    removing:
                        _removingIds
                            .contains(
                      item.id,
                    ),
                    onSelectionChanged:
                        () {
                      _toggleItemSelection(
                        item,
                      );
                    },
                    onProductTap:
                        () {
                      widget
                          .onProductSelected
                          ?.call(
                        item,
                      );
                    },
                    onRemove:
                        () {
                      _removeItem(
                        item,
                      );
                    },
                    onDecrease:
                        () {
                      _changeQuantity(
                        item,
                        item.quantity -
                            1,
                      );
                    },
                    onIncrease:
                        () {
                      _changeQuantity(
                        item,
                        item.quantity +
                            1,
                      );
                    },
                  ),
                );
              },
              childCount:
                  _items.length,
            ),
          ),
        ),

        SliverPadding(
          padding:
              const EdgeInsets.fromLTRB(
            14,
            20,
            14,
            0,
          ),
          sliver:
              SliverToBoxAdapter(
            child: Column(
              children: [
                _buildDeliveryAddress(),

                const SizedBox(
                  height: 14,
                ),

                _buildCartSummary(),

                const SizedBox(
                  height: 125,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeading() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR SELECTION',
                style:
                    TextStyle(
                  color: _maroon,
                  fontSize: 12,
                  letterSpacing:
                      1.6,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              SizedBox(
                height: 5,
              ),

              Text(
                'Your Cart',
                style:
                    TextStyle(
                  color: _text,
                  fontSize: 30,
                  height: 1,
                  letterSpacing:
                      -0.7,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              SizedBox(
                height: 6,
              ),

              Text(
                'Choose which products you want to send to checkout.',
                style:
                    TextStyle(
                  color: _muted,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Text(
          '${_items.length} ${_items.length == 1 ? 'item' : 'items'}',
          style:
              const TextStyle(
            color: _brown,
            fontSize: 13,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionHeader() {
    final bool hasAvailable =
        _availableItems.isNotEmpty;

    return Container(
      height: 52,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration:
          BoxDecoration(
        color: _surface,
        border:
            Border.all(
          color: _border,
        ),
        borderRadius:
            BorderRadius.circular(
          15,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            tristate: true,
            value:
                _allSelected
                    ? true
                    : _someSelected
                        ? null
                        : false,
            activeColor:
                _maroon,
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                4,
              ),
            ),
            onChanged:
                hasAvailable
                    ? (_) {
                        _toggleSelectAll();
                      }
                    : null,
          ),

          GestureDetector(
            onTap:
                hasAvailable
                    ? _toggleSelectAll
                    : null,
            child:
                const Text(
              'Select all available',
              style:
                  TextStyle(
                color: _text,
                fontSize: 13.5,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),

          const Spacer(),

          if (_selectedItems
              .isNotEmpty)
            TextButton(
              onPressed:
                  _removingSelected
                      ? null
                      : _removeSelected,
              child:
                  _removingSelected
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                            color:
                                _danger,
                          ),
                        )
                      : const Text(
                          'Remove selected',
                          style:
                              TextStyle(
                            color:
                                _danger,
                            fontSize:
                                13,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnavailableNotice() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFFFF4ED,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFF2D2BE,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons
                .info_outline_rounded,
            color: _danger,
            size: 18,
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Text(
              '$_unavailableCount ${_unavailableCount == 1 ? 'item is' : 'items are'} currently out of stock and cannot be selected for checkout.',
              style:
                  const TextStyle(
                color: _brown,
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddress() {
    final DeliveryAddressData? address =
        widget.defaultAddress;

    return _SectionCard(
      title:
          'Delivery Address',
      subtitle:
          'Preview your saved address. You can still confirm or change it during checkout.',
      trailing:
          TextButton(
        onPressed:
            widget.onChangeAddress,
        child: Text(
          address == null
              ? 'Add'
              : 'Change',
          style:
              const TextStyle(
            color: _maroon,
            fontSize: 13,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
      child:
          address == null
              ? Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    15,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFFFF7ED,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    border:
                        Border.all(
                      color:
                          const Color(
                        0xFFF0D7B5,
                      ),
                    ),
                  ),
                  child:
                      const Row(
                    children: [
                      Icon(
                        Icons
                            .location_off_outlined,
                        color:
                            _maroon,
                        size: 21,
                      ),

                      SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child: Text(
                          'No default delivery address is saved. You can add or choose an address during checkout.',
                          style:
                              TextStyle(
                            color:
                                _text,
                            fontSize:
                                13,
                            height:
                                1.4,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFFFF7F3,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    border:
                        Border.all(
                      color:
                          const Color(
                        0xFFE7C6B7,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration:
                            const BoxDecoration(
                          color:
                              Color(
                            0xFFF1E4D7,
                          ),
                          shape:
                              BoxShape.circle,
                        ),
                        alignment:
                            Alignment.center,
                        child:
                            const Icon(
                          Icons
                              .location_on_outlined,
                          color:
                              _maroon,
                          size: 20,
                        ),
                      ),

                      const SizedBox(
                        width: 11,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 7,
                              runSpacing:
                                  5,
                              crossAxisAlignment:
                                  WrapCrossAlignment.center,
                              children: [
                                Text(
                                  address
                                      .recipientName,
                                  style:
                                      const TextStyle(
                                    color:
                                        _text,
                                    fontSize:
                                        14,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),

                                if (address
                                    .contactNumber
                                    .trim()
                                    .isNotEmpty)
                                  Text(
                                    address
                                        .contactNumber,
                                    style:
                                        const TextStyle(
                                      color:
                                          _muted,
                                      fontSize:
                                          12.5,
                                    ),
                                  ),

                                if (address
                                    .isDefault)
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal:
                                          7,
                                      vertical:
                                          3,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          const Color(
                                        0xFFF1E4D7,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(
                                        100,
                                      ),
                                    ),
                                    child:
                                        const Text(
                                      'DEFAULT',
                                      style:
                                          TextStyle(
                                        color:
                                            _maroon,
                                        fontSize:
                                            11,
                                        letterSpacing:
                                            0.5,
                                        fontWeight:
                                            FontWeight.w900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(
                              height: 7,
                            ),

                            Text(
                              address
                                  .formattedAddress,
                              style:
                                  const TextStyle(
                                color:
                                    _muted,
                                fontSize:
                                    13,
                                height:
                                    1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCartSummary() {
    return _SectionCard(
      title:
          'Cart Summary',
      subtitle:
          'Only selected products will continue to checkout.',
      child: Column(
        children: [
          _SummaryRow(
            label:
                'Selected products',
            value:
                '${_selectedItems.length}',
          ),

          const SizedBox(
            height: 11,
          ),

          _SummaryRow(
            label:
                'Total quantity',
            value:
                '$_selectedQuantity',
          ),

          const SizedBox(
            height: 15,
          ),

          const Divider(
            color: _border,
            height: 1,
          ),

          const SizedBox(
            height: 15,
          ),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Product subtotal',
                  style:
                      TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),

              Text(
                _formatPrice(
                  _subtotal,
                ),
                style:
                    const TextStyle(
                  color: _maroon,
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing:
                      -0.3,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 13,
          ),

          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.all(
              11,
            ),
            decoration:
                BoxDecoration(
              color: _soft,
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child:
                const Text(
              'Courier fees, vouchers, payment method, and the final payable total are handled on the Checkout page.',
              style:
                  TextStyle(
                color: _muted,
                fontSize: 12,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCheckoutBar() {
    final bool canCheckout =
        _selectedItems.isNotEmpty;

    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          14,
          10,
          14,
          10,
        ),
        decoration:
            BoxDecoration(
          color: _surface,
          border:
              const Border(
            top:
                BorderSide(
              color: _border,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black
                      .withValues(
                alpha: 0.06,
              ),
              blurRadius: 20,
              offset:
                  const Offset(
                0,
                -6,
              ),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_selectedQuantity selected',
                    style:
                        const TextStyle(
                      color:
                          _muted,
                      fontSize:
                          12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                    height: 2,
                  ),

                  Text(
                    _formatPrice(
                      _subtotal,
                    ),
                    style:
                        const TextStyle(
                      color:
                          _maroon,
                      fontSize:
                          22,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            SizedBox(
              height: 54,
              child:
                  ElevatedButton(
                onPressed:
                    !canCheckout ||
                            _openingCheckout
                        ? null
                        : _openCheckout,
                style:
                    ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor:
                      _maroon,
                  foregroundColor:
                      Colors.white,
                  disabledBackgroundColor:
                      const Color(
                    0xFFD8D2CB,
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 22,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),
                ),
                child:
                    _openingCheckout
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              Text(
                                'Checkout',
                                style:
                                    TextStyle(
                                  fontSize:
                                      14,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),

                              SizedBox(
                                width: 6,
                              ),

                              Icon(
                                Icons
                                    .arrow_forward_rounded,
                                size: 17,
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatPrice(
    double value,
  ) {
    return '₱${value.toStringAsFixed(2)}';
  }
}

class _CartItemCard
    extends StatelessWidget {
  final CartItemData item;

  final bool selected;
  final bool updating;
  final bool removing;

  final VoidCallback
      onSelectionChanged;

  final VoidCallback
      onProductTap;

  final VoidCallback onRemove;

  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _CartItemCard({
    required this.item,
    required this.selected,
    required this.updating,
    required this.removing,
    required this.onSelectionChanged,
    required this.onProductTap,
    required this.onRemove,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool unavailable =
        !item.isAvailable;

    return AnimatedOpacity(
      opacity:
          removing
              ? 0.55
              : 1,
      duration:
          const Duration(
        milliseconds: 160,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          12,
        ),
        decoration:
            BoxDecoration(
          color:
              const Color(
            0xFFFFFDF9,
          ),
          borderRadius:
              BorderRadius.circular(
            17,
          ),
          border:
              Border.all(
            color:
                selected
                    ? const Color(
                        0xFFD9B99D,
                      )
                    : unavailable
                        ? const Color(
                            0xFFF0CFC8,
                          )
                        : const Color(
                            0xFFEADCCC,
                          ),
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value:
                      selected,
                  activeColor:
                      const Color(
                    0xFF561C17,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      4,
                    ),
                  ),
                  onChanged:
                      removing ||
                              unavailable
                          ? null
                          : (_) {
                              onSelectionChanged();
                            },
                ),

                GestureDetector(
                  onTap:
                      onProductTap,
                  child: Stack(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        clipBehavior:
                            Clip.antiAlias,
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFF3ECE4,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            13,
                          ),
                          border:
                              Border.all(
                            color:
                                const Color(
                              0xFFEADCCC,
                            ),
                          ),
                        ),
                        child:
                            _CartProductImage(
                          imageUrl:
                              item.imageUrl,
                        ),
                      ),

                      if (unavailable)
                        Positioned.fill(
                          child:
                              Container(
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.black
                                      .withValues(
                                alpha: 0.42,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                13,
                              ),
                            ),
                            alignment:
                                Alignment.center,
                            child:
                                const Text(
                              'OUT OF\nSTOCK',
                              textAlign:
                                  TextAlign.center,
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                                fontSize:
                                    11.5,
                                height:
                                    1.2,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(
                  width: 11,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child:
                                GestureDetector(
                              onTap:
                                  onProductTap,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  if (item
                                      .category
                                      .trim()
                                      .isNotEmpty) ...[
                                    Text(
                                      item.category
                                          .toUpperCase(),
                                      maxLines:
                                          1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style:
                                          const TextStyle(
                                        color:
                                            Color(
                                          0xFF6C4936,
                                        ),
                                        fontSize:
                                            11.5,
                                        letterSpacing:
                                            0.7,
                                        fontWeight:
                                            FontWeight.w800,
                                      ),
                                    ),

                                    const SizedBox(
                                      height:
                                          4,
                                    ),
                                  ],

                                  Text(
                                    item.name,
                                    maxLines:
                                        2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
                                      color:
                                          Color(
                                        0xFF3B211B,
                                      ),
                                      fontSize:
                                          14,
                                      height:
                                          1.25,
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 6,
                          ),

                          SizedBox(
                            width: 32,
                            height: 32,
                            child:
                                IconButton(
                              padding:
                                  EdgeInsets.zero,
                              tooltip:
                                  'Remove item',
                              onPressed:
                                  removing
                                      ? null
                                      : onRemove,
                              icon:
                                  removing
                                      ? const SizedBox(
                                          width:
                                              16,
                                          height:
                                              16,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth:
                                                2,
                                            color:
                                                Color(
                                              0xFFB42318,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons
                                              .delete_outline_rounded,
                                          color:
                                              Color(
                                            0xFFB42318,
                                          ),
                                          size:
                                              18,
                                        ),
                            ),
                          ),
                        ],
                      ),

                      if (item
                          .seller
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          item.seller,
                          maxLines:
                              1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Color(
                              0xFF987865,
                            ),
                            fontSize:
                                12,
                          ),
                        ),
                      ],

                      if (item
                          .variant
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          'Variant: ${item.variant}',
                          maxLines:
                              1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Color(
                              0xFFA99386,
                            ),
                            fontSize:
                                12,
                          ),
                        ),
                      ],

                      if (unavailable) ...[
                        const SizedBox(
                          height: 5,
                        ),

                        const Text(
                          'Currently unavailable',
                          style:
                              TextStyle(
                            color:
                                Color(
                              0xFFB42318,
                            ),
                            fontSize:
                                11.5,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            const Divider(
              color:
                  Color(
                0xFFF0E8DF,
              ),
              height: 1,
            ),

            const SizedBox(
              height: 11,
            ),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing:
                            5,
                        crossAxisAlignment:
                            WrapCrossAlignment.center,
                        children: [
                          Text(
                            _price(
                              item.price,
                            ),
                            style:
                                const TextStyle(
                              color:
                                  Color(
                                0xFF561C17,
                              ),
                              fontSize:
                                  15,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),

                          if (item.oldPrice !=
                                  null &&
                              item.oldPrice! >
                                  item.price)
                            Text(
                              _price(
                                item.oldPrice!,
                              ),
                              style:
                                  const TextStyle(
                                color:
                                    Color(
                                  0xFFA99386,
                                ),
                                fontSize:
                                    11.5,
                                decoration:
                                    TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        unavailable
                            ? 'Out of stock'
                            : '${item.stock} available',
                        style:
                            TextStyle(
                          color:
                              unavailable
                                  ? const Color(
                                      0xFFB42318,
                                    )
                                  : const Color(
                                      0xFFA99386,
                                    ),
                          fontSize:
                              11.5,
                          fontWeight:
                              unavailable
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                _QuantityControl(
                  quantity:
                      item.quantity,
                  canDecrease:
                      item.isAvailable &&
                      item.quantity >
                          1,
                  canIncrease:
                      item.isAvailable &&
                      item.quantity <
                          item.stock,
                  loading:
                      updating,
                  onDecrease:
                      onDecrease,
                  onIncrease:
                      onIncrease,
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            Row(
              children: [
                const Text(
                  'Item subtotal',
                  style:
                      TextStyle(
                    color:
                        Color(
                      0xFF987865,
                    ),
                    fontSize:
                        12,
                  ),
                ),

                const Spacer(),

                Text(
                  _price(
                    item.lineTotal,
                  ),
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF3B211B,
                    ),
                    fontSize:
                        14,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _price(
    double value,
  ) {
    return '₱${value.toStringAsFixed(2)}';
  }
}

class _QuantityControl
    extends StatelessWidget {
  final int quantity;

  final bool canDecrease;
  final bool canIncrease;

  final bool loading;

  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _QuantityControl({
    required this.quantity,
    required this.canDecrease,
    required this.canIncrease,
    required this.loading,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height: 36,
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFDBCEC1,
          ),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          _quantityButton(
            icon:
                Icons
                    .remove_rounded,
            enabled:
                canDecrease &&
                !loading,
            onTap:
                onDecrease,
          ),

          Container(
            width: 42,
            alignment:
                Alignment.center,
            decoration:
                const BoxDecoration(
              border: Border(
                left:
                    BorderSide(
                  color:
                      Color(
                    0xFFEADCCC,
                  ),
                ),
                right:
                    BorderSide(
                  color:
                      Color(
                    0xFFEADCCC,
                  ),
                ),
              ),
            ),
            child:
                loading
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                          color:
                              Color(
                            0xFF561C17,
                          ),
                        ),
                      )
                    : Text(
                        '$quantity',
                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF3B211B,
                          ),
                          fontSize:
                              13,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
          ),

          _quantityButton(
            icon:
                Icons
                    .add_rounded,
            enabled:
                canIncrease &&
                !loading,
            onTap:
                onIncrease,
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap:
          enabled
              ? onTap
              : null,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(
          icon,
          size: 15,
          color:
              enabled
                  ? const Color(
                      0xFF561C17,
                    )
                  : const Color(
                      0xFFC9C2BA,
                    ),
        ),
      ),
    );
  }
}

class _SectionCard
    extends StatelessWidget {
  final String title;
  final String subtitle;

  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFFFFDF9,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFEADCCC,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              15,
              14,
              10,
              13,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF3B211B,
                          ),
                          fontSize:
                              15,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        subtitle,
                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF987865,
                          ),
                          fontSize:
                              12.5,
                          height:
                              1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                ?trailing,
              ],
            ),
          ),

          const Divider(
            color:
                Color(
              0xFFF0E8DF,
            ),
            height: 1,
          ),

          Padding(
            padding:
                const EdgeInsets.all(
              15,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style:
                const TextStyle(
              color:
                  Color(
                0xFF987865,
              ),
              fontSize:
                  13,
            ),
          ),
        ),

        Text(
          value,
          style:
              const TextStyle(
            color:
                Color(
              0xFF3B211B,
            ),
            fontSize:
                13,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CartProductImage
    extends StatelessWidget {
  final String? imageUrl;

  const _CartProductImage({
    required this.imageUrl,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final String? url =
        imageUrl?.trim();

    if (url == null ||
        url.isEmpty) {
      return const Center(
        child: Icon(
          Icons
              .image_outlined,
          color:
              Color(
            0xFFA99386,
          ),
          size: 31,
        ),
      );
    }

    final String resolvedUrl = AppConfig.resolveMediaUrl(url);

    return Image.network(
      resolvedUrl,
      fit: BoxFit.cover,
      loadingBuilder:
          (
        BuildContext context,
        Widget child,
        ImageChunkEvent? progress,
      ) {
        if (progress == null) {
          return child;
        }

        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child:
                CircularProgressIndicator(
              strokeWidth: 2,
              color:
                  Color(
                0xFF561C17,
              ),
            ),
          ),
        );
      },
      errorBuilder:
          (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return const Center(
          child: Icon(
            Icons
                .broken_image_outlined,
            color:
                Color(
              0xFFA99386,
            ),
            size: 31,
          ),
        );
      },
    );
  }
}