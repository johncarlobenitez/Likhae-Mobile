import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:likhae/core/config/app_config.dart';

import '../../../shared/widgets/sized_network_image.dart';
import '../../../shared/widgets/shop_ui.dart';
import '../checkout/shop_voucher_picker.dart';
import '../checkout/voucher_discount_calculator.dart';
import '../rewards/rewards_screen.dart';

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

  final bool isActive;
  final bool sellerOnVacation;
  final bool serverAvailable;

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
    this.isActive = true,
    this.sellerOnVacation = false,
    this.serverAvailable = true,
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
    return stock > 0 && isActive && !sellerOnVacation && serverAvailable;
  }

  String get unavailableMessage => sellerOnVacation
      ? 'Seller is on vacation and cannot accept orders.'
      : stock < 1
      ? 'This item is currently out of stock.'
      : 'This item is currently unavailable for purchase.';

  CartItemData copyWith({int? quantity, int? stock}) {
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
      isActive: isActive,
      sellerOnVacation: sellerOnVacation,
      serverAvailable: serverAvailable,
      imageUrl: imageUrl,
    );
  }
}

String _formatCartAmount(double value) {
  final String fixed = value.abs().toStringAsFixed(2);
  final List<String> parts = fixed.split('.');
  final String whole = parts.first;
  final StringBuffer grouped = StringBuffer();
  for (int index = 0; index < whole.length; index++) {
    final int remaining = whole.length - index;
    grouped.write(whole[index]);
    if (remaining > 1 && remaining % 3 == 1) grouped.write(',');
  }

  final String sign = value < 0 ? '-' : '';
  return '₱$sign$grouped.${parts.last}';
}

class DeliveryAddressData {
  final String? id;
  final String recipientName;
  final String contactNumber;
  final String formattedAddress;

  final bool isDefault;

  const DeliveryAddressData({
    required this.recipientName,
    required this.contactNumber,
    required this.formattedAddress,
    this.id,
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
      if (productId != null) 'product_id': productId,
      if (productVariationId != null)
        'product_variation_id': productVariationId,
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
  final Map<int, String> voucherCodes;
  final String? platformVoucherCode;
  final String? shippingVoucherCode;

  const CartCheckoutRequest({
    required this.items,
    this.checkoutSource = 'cart',
    this.voucherCodes = const <int, String>{},
    this.platformVoucherCode,
    this.shippingVoucherCode,
  });

  List<Map<String, dynamic>> get itemPayload {
    return items.map((CartCheckoutItem item) => item.toMap()).toList();
  }
}

typedef CartQuantityUpdateCallback =
    Future<void> Function(CartItemData item, int quantity);

typedef CartRemoveCallback = Future<void> Function(CartItemData item);

typedef CartRemoveSelectedCallback =
    Future<void> Function(List<CartItemData> items);

typedef CartCheckoutCallback =
    Future<void> Function(CartCheckoutRequest request);

typedef CartRefreshCallback = Future<List<CartItemData>> Function();

typedef CartQuoteCallback =
    Future<Map<String, dynamic>> Function({
      required List<CartItemData> items,
      required int addressId,
      required Map<int, String> voucherCodes,
      String? platformVoucherCode,
      String? shippingVoucherCode,
    });

typedef CartSellerSelectedCallback =
    void Function(String sellerName, int? sellerId);

class CartScreen extends StatefulWidget {
  final List<CartItemData> items;

  final DeliveryAddressData? defaultAddress;

  final VoidCallback? onBack;
  final VoidCallback? onContinueShopping;
  final VoidCallback? onChangeAddress;

  final ValueChanged<CartItemData>? onProductSelected;

  final CartSellerSelectedCallback? onSellerSelected;

  final CartQuantityUpdateCallback? onUpdateQuantity;

  final CartRemoveCallback? onRemoveItem;

  final CartRemoveSelectedCallback? onRemoveSelected;

  /// This should navigate to Checkout.
  ///
  /// It should NOT create an order.
  ///
  /// Place Order belongs to checkout_screen.dart.
  final CartCheckoutCallback? onCheckout;

  final CartRefreshCallback? onRefresh;

  final CartQuoteCallback? onLoadQuote;

  final Future<List<RewardVoucherData>> Function()? loadAvailableVouchers;
  final Map<int, String> initialVoucherCodes;
  final String? initialPlatformVoucherCode;
  final String? initialShippingVoucherCode;

  const CartScreen({
    super.key,
    this.items = const <CartItemData>[],
    this.defaultAddress,
    this.onBack,
    this.onContinueShopping,
    this.onChangeAddress,
    this.onProductSelected,
    this.onSellerSelected,
    this.onUpdateQuantity,
    this.onRemoveItem,
    this.onRemoveSelected,
    this.onCheckout,
    this.onRefresh,
    this.onLoadQuote,
    this.loadAvailableVouchers,
    this.initialVoucherCodes = const <int, String>{},
    this.initialPlatformVoucherCode,
    this.initialShippingVoucherCode,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const Color _background = ShopColors.canvas;

  static const Color _surface = ShopColors.surface;

  static const Color _soft = ShopColors.soft;

  static const Color _border = ShopColors.border;

  static const Color _maroon = ShopColors.accent;

  static const Color _maroonDark = ShopColors.accentDark;

  static const Color _text = ShopColors.text;

  static const Color _muted = ShopColors.muted;

  static const Color _brown = ShopColors.secondaryText;

  static const Color _danger = Color(0xFFB42318);

  late List<CartItemData> _items;

  final Set<String> _selectedIds = <String>{};
  final Set<String> _deleteSelectedIds = <String>{};

  final Set<String> _updatingIds = <String>{};

  final Set<String> _removingIds = <String>{};

  bool _editMode = false;
  bool _removingSelected = false;
  bool _openingCheckout = false;
  bool _openingVoucherPicker = false;
  bool _loadingQuote = false;
  Map<String, dynamic>? _serverQuote;
  String? _quoteError;
  Timer? _quoteDebounce;
  int _quoteRequestVersion = 0;
  List<RewardVoucherData>? _availableVouchers;
  Future<List<RewardVoucherData>>? _voucherLoad;
  final Map<int, String> _selectedVoucherCodes = <int, String>{};
  String? _selectedPlatformVoucherCode;
  String? _selectedShippingVoucherCode;

  @override
  void initState() {
    super.initState();

    _items = List<CartItemData>.from(widget.items);

    _selectedVoucherCodes.addAll(widget.initialVoucherCodes);
    _selectedPlatformVoucherCode = widget.initialPlatformVoucherCode;
    _selectedShippingVoucherCode = widget.initialShippingVoucherCode;
    if (widget.loadAvailableVouchers != null) {
      unawaited(_preloadVouchers());
    }
    _scheduleCartQuote();
  }

  @override
  void didUpdateWidget(covariant CartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.items != widget.items) {
      final Set<String> previousSelection = Set<String>.from(_selectedIds);

      _items = List<CartItemData>.from(widget.items);

      _selectedVoucherCodes.removeWhere(
        (int sellerId, String _) =>
            !_items.any((CartItemData item) => item.sellerId == sellerId),
      );

      final Set<String> currentAvailableIds = _availableItems
          .map((CartItemData item) => item.id)
          .toSet();

      _selectedIds
        ..clear()
        ..addAll(previousSelection.intersection(currentAvailableIds));

      final Set<String> currentItemIds = _items
          .map((CartItemData item) => item.id)
          .toSet();
      _deleteSelectedIds.removeWhere(
        (String id) => !currentItemIds.contains(id),
      );
      if (_items.isEmpty) {
        _editMode = false;
        _deleteSelectedIds.clear();
      }
      _scheduleCartQuote();
    }
    if (oldWidget.defaultAddress?.id != widget.defaultAddress?.id) {
      _scheduleCartQuote();
    }
  }

  List<CartItemData> get _availableItems {
    return _items.where((CartItemData item) => item.isAvailable).toList();
  }

  List<CartItemData> get _selectedItems {
    return _items
        .where(
          (CartItemData item) =>
              item.isAvailable && _selectedIds.contains(item.id),
        )
        .toList();
  }

  bool get _allSelected {
    if (_availableItems.isEmpty) {
      return false;
    }

    return _availableItems.every(
      (CartItemData item) => _selectedIds.contains(item.id),
    );
  }

  bool get _someSelected {
    return _selectedItems.isNotEmpty && !_allSelected;
  }

  List<_CartSellerGroup> get _sellerGroups {
    final Map<String, _CartSellerGroup> groups = <String, _CartSellerGroup>{};

    for (final CartItemData item in _items) {
      final String key = _sellerGroupKey(item);
      final _CartSellerGroup group = groups.putIfAbsent(
        key,
        () => _CartSellerGroup(
          name: item.seller.trim().isEmpty ? 'Seller' : item.seller.trim(),
        ),
      );
      group.items.add(item);
    }

    return groups.values.toList(growable: false);
  }

  String _sellerGroupKey(CartItemData item) {
    final int? sellerId = item.sellerId;
    if (sellerId != null && sellerId > 0) {
      return 'id:$sellerId';
    }

    final String sellerName = item.seller.trim().toLowerCase();
    if (sellerName.isNotEmpty && sellerName != 'seller') {
      return 'name:$sellerName';
    }

    // Do not accidentally merge unrelated items when the backend did not
    // include enough seller information to identify the owner.
    return 'item:${item.id}';
  }

  int get _selectedQuantity {
    return _selectedItems.fold<int>(
      0,
      (int total, CartItemData item) => total + item.quantity,
    );
  }

  double get _subtotal {
    return _selectedItems.fold<double>(
      0,
      (double total, CartItemData item) => total + item.lineTotal,
    );
  }

  double get _shopVoucherDiscount {
    final dynamic quotedDiscount = _serverQuote?['total_discount'];
    if (quotedDiscount != null) {
      return double.tryParse(quotedDiscount.toString()) ?? 0;
    }
    if (_availableVouchers == null || _selectedVoucherCodes.isEmpty) return 0;

    double total = 0;
    for (final MapEntry<int, String> selection
        in _selectedVoucherCodes.entries) {
      final List<CartItemData> sellerItems = _selectedItems
          .where((CartItemData item) => item.sellerId == selection.key)
          .toList(growable: false);
      if (sellerItems.isEmpty) continue;

      final RewardVoucherData? voucher = _voucherForSeller(
        selection.key,
        selection.value,
      );
      if (voucher == null) continue;

      final double sellerSubtotal = sellerItems.fold<double>(
        0,
        (double subtotal, CartItemData item) => subtotal + item.lineTotal,
      );
      total += calculateSellerVoucherDiscount(voucher, sellerSubtotal);
    }

    return total.clamp(0, _subtotal).toDouble();
  }

  RewardVoucherData? _voucherForSeller(int sellerId, String code) {
    for (final RewardVoucherData voucher
        in _availableVouchers ?? const <RewardVoucherData>[]) {
      if (voucher.sellerId == sellerId &&
          voucher.code.trim().toUpperCase() == code.trim().toUpperCase()) {
        return voucher;
      }
    }
    return null;
  }

  Map<int, String> _eligibleVoucherCodes(List<CartItemData> selectedItems) {
    final Map<int, String> eligible = <int, String>{};
    for (final MapEntry<int, String> selection
        in _selectedVoucherCodes.entries) {
      final List<CartItemData> sellerItems = selectedItems
          .where((CartItemData item) => item.sellerId == selection.key)
          .toList(growable: false);
      if (sellerItems.isEmpty) continue;

      final RewardVoucherData? voucher = _voucherForSeller(
        selection.key,
        selection.value,
      );
      if (_availableVouchers != null && voucher == null) continue;
      if (voucher != null) {
        final double sellerSubtotal = sellerItems.fold<double>(
          0,
          (double subtotal, CartItemData item) => subtotal + item.lineTotal,
        );
        if (voucher.canUse == false ||
            sellerSubtotal < (voucher.minimumOrderAmount ?? 0)) {
          continue;
        }
      }

      eligible[selection.key] = selection.value;
    }
    return eligible;
  }

  VoucherCodesSelection _eligibleVoucherSelection(
    List<CartItemData> selectedItems,
  ) {
    final double selectedSubtotal = selectedItems.fold<double>(
      0,
      (double total, CartItemData item) => total + item.lineTotal,
    );
    String? eligibleGlobalCode(String? code, String type) {
      if (code == null || code.trim().isEmpty || _availableVouchers == null) {
        return code;
      }
      for (final RewardVoucherData voucher in _availableVouchers!) {
        if (voucher.voucherType == type &&
            voucher.code.trim().toUpperCase() == code.trim().toUpperCase() &&
            voucher.canUse != false &&
            selectedSubtotal >= (voucher.minimumOrderAmount ?? 0)) {
          return code;
        }
      }
      return null;
    }

    return VoucherCodesSelection(
      sellerCodes: _eligibleVoucherCodes(selectedItems),
      platformCode: eligibleGlobalCode(
        _selectedPlatformVoucherCode,
        'platform',
      ),
      shippingCode: eligibleGlobalCode(
        _selectedShippingVoucherCode,
        'shipping',
      ),
    );
  }

  int get _unavailableCount {
    return _items.where((CartItemData item) => !item.isAvailable).length;
  }

  void _selectAllAvailable() {
    _selectedIds
      ..clear()
      ..addAll(
        _items
            .where((CartItemData item) => item.isAvailable)
            .map((CartItemData item) => item.id),
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
    _scheduleCartQuote();
  }

  void _toggleItemSelection(CartItemData item) {
    if (!item.isAvailable) {
      _showMessage(item.unavailableMessage, error: true);

      return;
    }

    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
    _scheduleCartQuote();
  }

  bool _isSellerGroupSelected(_CartSellerGroup group) {
    final List<CartItemData> availableItems = group.items
        .where((CartItemData item) => item.isAvailable)
        .toList(growable: false);
    return availableItems.isNotEmpty &&
        availableItems.every(
          (CartItemData item) => _selectedIds.contains(item.id),
        );
  }

  bool _isSellerGroupPartiallySelected(_CartSellerGroup group) {
    final List<CartItemData> availableItems = group.items
        .where((CartItemData item) => item.isAvailable)
        .toList(growable: false);
    final bool hasSelected = availableItems.any(
      (CartItemData item) => _selectedIds.contains(item.id),
    );
    return hasSelected && !_isSellerGroupSelected(group);
  }

  bool _isSellerGroupDeleteSelected(_CartSellerGroup group) {
    return group.items.isNotEmpty &&
        group.items.every(
          (CartItemData item) => _deleteSelectedIds.contains(item.id),
        );
  }

  bool _isSellerGroupPartiallyDeleteSelected(_CartSellerGroup group) {
    final bool hasSelected = group.items.any(
      (CartItemData item) => _deleteSelectedIds.contains(item.id),
    );
    return hasSelected && !_isSellerGroupDeleteSelected(group);
  }

  void _toggleEditMode() {
    final bool wasEditing = _editMode;
    setState(() {
      _editMode = !_editMode;
      _deleteSelectedIds.clear();
    });
    if (wasEditing) _scheduleCartQuote();
  }

  void _toggleDeleteItemSelection(CartItemData item) {
    setState(() {
      if (!_deleteSelectedIds.add(item.id)) {
        _deleteSelectedIds.remove(item.id);
      }
    });
  }

  void _toggleDeleteSellerGroup(_CartSellerGroup group) {
    final bool allSelected = _isSellerGroupDeleteSelected(group);
    setState(() {
      for (final CartItemData item in group.items) {
        if (allSelected) {
          _deleteSelectedIds.remove(item.id);
        } else {
          _deleteSelectedIds.add(item.id);
        }
      }
    });
  }

  void _toggleAllForRemoval() {
    setState(() {
      if (_items.isNotEmpty && _deleteSelectedIds.length == _items.length) {
        _deleteSelectedIds.clear();
      } else {
        _deleteSelectedIds
          ..clear()
          ..addAll(_items.map((CartItemData item) => item.id));
      }
    });
  }

  void _toggleSellerGroup(_CartSellerGroup group) {
    final List<String> availableIds = group.items
        .where((CartItemData item) => item.isAvailable)
        .map((CartItemData item) => item.id)
        .toList(growable: false);

    if (availableIds.isEmpty) {
      return;
    }

    setState(() {
      if (_isSellerGroupSelected(group)) {
        _selectedIds.removeAll(availableIds);
      } else {
        _selectedIds.addAll(availableIds);
      }
    });
    _scheduleCartQuote();
  }

  Future<void> _changeQuantity(CartItemData item, int requestedQuantity) async {
    if (!item.isAvailable) {
      _showMessage(item.unavailableMessage, error: true);

      return;
    }

    if (_updatingIds.contains(item.id)) {
      return;
    }

    final int quantity = math
        .min(item.stock, math.max(1, requestedQuantity))
        .toInt();

    if (quantity == item.quantity) {
      return;
    }

    final CartQuantityUpdateCallback? callback = widget.onUpdateQuantity;

    if (callback == null) {
      _showMessage('Cart quantity will be connected to Laravel later.');

      return;
    }

    setState(() {
      _updatingIds.add(item.id);
    });

    try {
      await callback(item, quantity);

      if (!mounted) {
        return;
      }

      final int index = _items.indexWhere(
        (CartItemData current) => current.id == item.id,
      );

      if (index >= 0) {
        setState(() {
          _items[index] = _items[index].copyWith(quantity: quantity);
        });
        _scheduleCartQuote();
      }
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _updatingIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _removeItem(CartItemData item) async {
    if (_removingIds.contains(item.id)) {
      return;
    }

    final bool confirmed = await _confirmRemoveSingle(item);

    if (!confirmed || !mounted) {
      return;
    }

    final CartRemoveCallback? callback = widget.onRemoveItem;

    if (callback == null) {
      _showMessage('Cart removal will be connected to Laravel later.');

      return;
    }

    setState(() {
      _removingIds.add(item.id);
    });

    try {
      await callback(item);

      if (!mounted) {
        return;
      }

      setState(() {
        _items.removeWhere((CartItemData current) => current.id == item.id);

        _selectedIds.remove(item.id);
        _deleteSelectedIds.remove(item.id);
      });
      _scheduleCartQuote();

      _showMessage('${item.name} removed from cart.');
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _removingIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _removeEditSelectedItems() async {
    final List<CartItemData> selected = _items
        .where((CartItemData item) => _deleteSelectedIds.contains(item.id))
        .toList(growable: false);
    if (selected.isEmpty || _removingSelected) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Remove selected items?',
          style: TextStyle(color: _text, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Remove ${selected.length} selected ${selected.length == 1 ? 'item' : 'items'} from your cart?',
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: _danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (widget.onRemoveSelected == null && widget.onRemoveItem == null) {
      _showMessage('Cart removal will be connected to Laravel later.');
      return;
    }

    final Set<String> successfullyRemoved = <String>{};
    setState(() {
      _removingSelected = true;
      _removingIds.addAll(selected.map((CartItemData item) => item.id));
    });

    try {
      if (widget.onRemoveItem != null) {
        for (final CartItemData item in selected) {
          await widget.onRemoveItem!(item);
          successfullyRemoved.add(item.id);
        }
      } else {
        await widget.onRemoveSelected!(selected);
        successfullyRemoved.addAll(
          selected.map((CartItemData item) => item.id),
        );
      }

      if (!mounted) return;
      _removeItemsLocally(successfullyRemoved);
      _showMessage(
        selected.length == 1
            ? 'Item removed from cart.'
            : 'Items removed from cart.',
      );
    } catch (error) {
      if (!mounted) return;
      if (successfullyRemoved.isNotEmpty) {
        _removeItemsLocally(successfullyRemoved);
      }
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _removingSelected = false;
          _removingIds.removeAll(selected.map((CartItemData item) => item.id));
        });
      }
    }
  }

  void _removeItemsLocally(Set<String> ids) {
    if (ids.isEmpty) return;
    setState(() {
      _items.removeWhere((CartItemData item) => ids.contains(item.id));
      _selectedIds.removeAll(ids);
      _deleteSelectedIds.removeAll(ids);
      if (_items.isEmpty) _editMode = false;
      _selectedVoucherCodes.removeWhere(
        (int sellerId, String _) =>
            !_items.any((CartItemData item) => item.sellerId == sellerId),
      );
    });
  }

  Future<bool> _confirmRemoveSingle(CartItemData item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Remove item?',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Remove ${item.name} from your cart?',
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _openCheckout() async {
    if (_openingCheckout) {
      return;
    }

    final List<CartItemData> selected = _selectedItems;

    if (selected.isEmpty) {
      _showMessage(
        'Select at least one available cart item before checkout.',
        error: true,
      );

      return;
    }

    final CartCheckoutCallback? callback = widget.onCheckout;

    if (callback == null) {
      _showMessage('Checkout navigation will be connected later.');

      return;
    }

    final VoucherCodesSelection eligibleVouchers = _eligibleVoucherSelection(
      selected,
    );
    final bool voucherSelectionChanged =
        eligibleVouchers.sellerCodes.length != _selectedVoucherCodes.length ||
        eligibleVouchers.sellerCodes.entries.any(
          (MapEntry<int, String> entry) =>
              _selectedVoucherCodes[entry.key] != entry.value,
        ) ||
        eligibleVouchers.platformCode != _selectedPlatformVoucherCode ||
        eligibleVouchers.shippingCode != _selectedShippingVoucherCode;
    if (voucherSelectionChanged) {
      setState(() {
        _selectedVoucherCodes
          ..clear()
          ..addAll(eligibleVouchers.sellerCodes);
        _selectedPlatformVoucherCode = eligibleVouchers.platformCode;
        _selectedShippingVoucherCode = eligibleVouchers.shippingCode;
      });
      _scheduleCartQuote();
      _showMessage(
        'A voucher was removed because the selected items no longer qualify.',
      );
    }

    final CartCheckoutRequest request = CartCheckoutRequest(
      items: selected
          .map(
            (CartItemData item) => CartCheckoutItem(
              id: item.id,
              productId: item.productId,
              productVariationId: item.productVariationId,
              variant: item.variant,
              quantity: item.quantity,
            ),
          )
          .toList(),
      voucherCodes: eligibleVouchers.sellerCodes,
      platformVoucherCode: eligibleVouchers.platformCode,
      shippingVoucherCode: eligibleVouchers.shippingCode,
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
      await callback(request);
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _openingCheckout = false;
        });
      }
    }
  }

  Future<void> _preloadVouchers() async {
    try {
      await _loadAvailableVouchers();
    } catch (_) {
      // Keep the cart usable if the rewards endpoint is unavailable.
    }
  }

  Future<List<RewardVoucherData>> _loadAvailableVouchers() async {
    final List<RewardVoucherData>? cached = _availableVouchers;
    if (cached != null) return cached;

    final Future<List<RewardVoucherData>>? pending = _voucherLoad;
    if (pending != null) return pending;

    final Future<List<RewardVoucherData>> Function()? loader =
        widget.loadAvailableVouchers;
    if (loader == null) return const <RewardVoucherData>[];

    final Future<List<RewardVoucherData>> request = loader();
    _voucherLoad = request;
    try {
      final List<RewardVoucherData> vouchers = await request;
      _availableVouchers = vouchers;
      if (mounted) setState(() {});
      return vouchers;
    } finally {
      _voucherLoad = null;
    }
  }

  Map<int, String> _voucherSellerNames(List<CartItemData> items) {
    final Map<int, String> names = <int, String>{};
    for (final CartItemData item in items) {
      final int? sellerId = item.sellerId;
      if (sellerId == null || sellerId < 1) continue;
      names.putIfAbsent(
        sellerId,
        () => item.seller.trim().isEmpty ? 'Shop' : item.seller.trim(),
      );
    }
    return names;
  }

  Map<int, double> _voucherSellerSubtotals(List<CartItemData> items) {
    final Map<int, double> subtotals = <int, double>{};
    for (final CartItemData item in items) {
      final int? sellerId = item.sellerId;
      if (sellerId == null || sellerId < 1) continue;
      subtotals.update(
        sellerId,
        (double subtotal) => subtotal + item.lineTotal,
        ifAbsent: () => item.lineTotal,
      );
    }
    return subtotals;
  }

  Future<void> _openVoucherPicker() async {
    if (_openingVoucherPicker) return;
    if (widget.loadAvailableVouchers == null) {
      _showMessage('Connect the Laravel API to select available vouchers.');
      return;
    }

    final List<CartItemData> eligibleItems = _selectedItems;
    final Map<int, String> sellerNames = _voucherSellerNames(eligibleItems);
    if (sellerNames.isEmpty) {
      _showMessage('Select an available item from a shop to use its voucher.');
      return;
    }

    setState(() => _openingVoucherPicker = true);
    try {
      final List<RewardVoucherData> vouchers = await _loadAvailableVouchers();
      if (!mounted) return;
      final VoucherCodesSelection? result =
          await showModalBottomSheet<VoucherCodesSelection>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (BuildContext context) => ShopVoucherPicker(
              vouchers: vouchers,
              sellerNames: sellerNames,
              sellerSubtotals: _voucherSellerSubtotals(eligibleItems),
              initialCodes: _selectedVoucherCodes,
              initialPlatformCode: _selectedPlatformVoucherCode,
              initialShippingCode: _selectedShippingVoucherCode,
            ),
          );
      if (!mounted || result == null) return;
      setState(() {
        _selectedVoucherCodes
          ..clear()
          ..addAll(result.sellerCodes);
        _selectedPlatformVoucherCode = result.platformCode;
        _selectedShippingVoucherCode = result.shippingCode;
      });
      _scheduleCartQuote();
    } catch (error) {
      if (mounted) _showMessage('Unable to load shop vouchers: $error');
    } finally {
      if (mounted) setState(() => _openingVoucherPicker = false);
    }
  }

  Future<void> _refresh() async {
    final CartRefreshCallback? callback = widget.onRefresh;

    if (callback == null) {
      return;
    }

    try {
      final List<CartItemData> items = await callback();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _selectedIds.removeWhere(
          (String id) => !items.any((CartItemData item) => item.id == id),
        );
        _deleteSelectedIds.removeWhere(
          (String id) => !items.any((CartItemData item) => item.id == id),
        );
        if (items.isEmpty) _editMode = false;
      });
      _scheduleCartQuote();
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    }
  }

  void _scheduleCartQuote() {
    _quoteDebounce?.cancel();
    final int requestVersion = ++_quoteRequestVersion;
    final CartQuoteCallback? callback = widget.onLoadQuote;
    final int? addressId = int.tryParse(widget.defaultAddress?.id ?? '');
    final List<CartItemData> selected = List<CartItemData>.unmodifiable(
      _selectedItems,
    );
    if (callback == null ||
        addressId == null ||
        selected.isEmpty ||
        _editMode) {
      if (mounted) {
        setState(() {
          _serverQuote = null;
          _quoteError = null;
          _loadingQuote = false;
        });
      }
      return;
    }
    setState(() {
      _loadingQuote = true;
      _quoteError = null;
      _serverQuote = null;
    });
    _quoteDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final VoucherCodesSelection voucherSelection =
            _eligibleVoucherSelection(selected);
        final Map<String, dynamic> quote = await callback(
          items: selected,
          addressId: addressId,
          voucherCodes: voucherSelection.sellerCodes,
          platformVoucherCode: voucherSelection.platformCode,
          shippingVoucherCode: voucherSelection.shippingCode,
        );
        if (!mounted || requestVersion != _quoteRequestVersion) return;
        setState(() {
          _serverQuote = quote;
          _loadingQuote = false;
        });
      } catch (error) {
        if (!mounted || requestVersion != _quoteRequestVersion) return;
        setState(() {
          _serverQuote = null;
          _quoteError = error.toString().replaceFirst('Exception: ', '');
          _loadingQuote = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _quoteDebounce?.cancel();
    _quoteRequestVersion++;
    super.dispose();
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
                child: _items.isEmpty ? _buildEmptyCart() : _buildCartContent(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _items.isEmpty
          ? null
          : _editMode
          ? _buildBottomEditBar()
          : _buildBottomCheckoutBar(),
    );
  }

  Widget _buildTopBar() {
    return ColoredBox(
      color: _surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassIconButton(
              icon: Icons.arrow_back_rounded,
              label: 'Back',
              onPressed:
                  widget.onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _editMode ? 'EDIT CART' : 'YOUR SELECTION',
                          style: TextStyle(
                            color: _maroon,
                            fontSize: 10,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${_items.length} ${_items.length == 1 ? 'item' : 'items'}',
                        style: const TextStyle(
                          color: _brown,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_items.isNotEmpty)
                        TextButton(
                          onPressed: _removingSelected ? null : _toggleEditMode,
                          style: TextButton.styleFrom(
                            foregroundColor: _maroon,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(44, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(_editMode ? 'Done' : 'Edit'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _editMode ? 'Edit Cart' : 'Your Cart',
                    style: TextStyle(
                      color: _text,
                      fontSize: 24,
                      height: 1.1,
                      letterSpacing: -0.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _editMode
                        ? 'Select products or shops you want to remove.'
                        : _items.isEmpty
                        ? 'A few good finds, ready for you.'
                        : 'Choose which products you want to send to checkout.',
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),

        Center(
          child: Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: ShopColors.accentSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.shopping_cart_outlined,
              color: _maroon,
              size: 36,
            ),
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          'Your cart is empty',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _text,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Browse the marketplace and add products you would like to purchase.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 14, height: 1.55),
        ),

        const SizedBox(height: 24),

        Center(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: widget.onContinueShopping,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _maroon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text(
                'Browse Products',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),

        const SizedBox(height: 34),

        const Text(
          'Items you add will appear here',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Your selected product image, name, variant, seller, price, and quantity will be shown in this section.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
        ),

        const SizedBox(height: 18),

        _buildCartItemPlaceholder(),

        const SizedBox(height: 10),

        _buildCartItemPlaceholder(),
      ],
    );
  }

  Widget _buildCartItemPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _border),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.image_outlined, color: _muted, size: 32),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 13,
                  width: 92,
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  height: 13,
                  width: 150,
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Container(
                      height: 16,
                      width: 82,
                      decoration: BoxDecoration(
                        color: _soft,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),

                    const Spacer(),

                    Container(
                      height: 32,
                      width: 92,
                      decoration: BoxDecoration(
                        color: _soft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
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
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                if (_unavailableCount > 0) ...[
                  const SizedBox(height: 2),

                  _buildUnavailableNotice(),
                ],

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverToBoxAdapter(child: _buildCartItemsContainer()),
        ),

        if (!_editMode)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildDeliveryAddress(),

                  const SizedBox(height: 14),

                  _buildCartSummary(),

                  const SizedBox(height: 170),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCartItemsContainer() {
    final List<_CartSellerGroup> groups = _sellerGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final _CartSellerGroup group in groups)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: _buildSellerGroup(group),
          ),
      ],
    );
  }

  Widget _buildSellerGroup(_CartSellerGroup group) {
    final bool groupSelected = _editMode
        ? _isSellerGroupDeleteSelected(group)
        : _isSellerGroupSelected(group);
    final bool groupPartiallySelected = _editMode
        ? _isSellerGroupPartiallyDeleteSelected(group)
        : _isSellerGroupPartiallySelected(group);
    final bool hasAvailableItem = group.items.any(
      (CartItemData item) => item.isAvailable,
    );

    final bool canViewShop =
        widget.onSellerSelected != null &&
        (group.sellerId != null || group.name.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
          decoration: const BoxDecoration(
            color: _soft,
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: Row(
            children: <Widget>[
              Checkbox(
                tristate: true,
                value: groupSelected
                    ? true
                    : groupPartiallySelected
                    ? null
                    : false,
                activeColor: _maroon,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                onChanged: _editMode
                    ? (_) => _toggleDeleteSellerGroup(group)
                    : hasAvailableItem
                    ? (_) => _toggleSellerGroup(group)
                    : null,
              ),
              Expanded(
                child: Text(
                  group.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 12,
                    letterSpacing: 0.55,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${group.items.length} ${group.items.length == 1 ? 'item' : 'items'}',
                style: const TextStyle(color: _muted, fontSize: 11.5),
              ),
              if (canViewShop) ...<Widget>[
                const SizedBox(width: 12),
                InkWell(
                  onTap: () =>
                      widget.onSellerSelected!(group.name, group.sellerId),
                  child: const Text(
                    'View Shop',
                    style: TextStyle(
                      color: _maroon,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        for (int index = 0; index < group.items.length; index++) ...<Widget>[
          if (index > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Divider(color: ShopColors.border, height: 1),
            ),
          _buildCartItem(group.items[index]),
        ],
        if (!_editMode) _buildShopVoucherRow(group),
      ],
    );
  }

  Widget _buildShopVoucherRow(_CartSellerGroup group) {
    final int? sellerId = group.sellerId;
    final String? selectedCode = sellerId == null
        ? null
        : _selectedVoucherCodes[sellerId];
    RewardVoucherData? availableVoucher;
    if (sellerId != null) {
      for (final RewardVoucherData voucher
          in _availableVouchers ?? const <RewardVoucherData>[]) {
        if (voucher.sellerId == sellerId && voucher.canUse != false) {
          availableVoucher = voucher;
          break;
        }
      }
    }

    final bool hasSelectedItems = group.items.any(
      (CartItemData item) => item.isAvailable && _selectedIds.contains(item.id),
    );
    final String label = selectedCode != null
        ? 'Voucher selected: $selectedCode'
        : availableVoucher != null
        ? '${availableVoucher.value.isEmpty ? 'Shop voucher' : availableVoucher.value} available'
        : 'Add shop voucher code';

    return Material(
      color: _surface,
      child: InkWell(
        onTap: hasSelectedItems && sellerId != null ? _openVoucherPicker : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.confirmation_number_outlined,
                color: ShopColors.accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (availableVoucher != null && selectedCode == null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ShopColors.accent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: ShopColors.faint,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItem(CartItemData item) {
    return _CartItemCard(
      item: item,
      selected: _editMode
          ? _deleteSelectedIds.contains(item.id)
          : _selectedIds.contains(item.id),
      editMode: _editMode,
      updating: _updatingIds.contains(item.id),
      removing: _removingIds.contains(item.id),
      onSelectionChanged: _editMode
          ? () => _toggleDeleteItemSelection(item)
          : () => _toggleItemSelection(item),
      onProductTap: () {
        widget.onProductSelected?.call(item);
      },
      onRemove: () {
        _removeItem(item);
      },
      onDecrease: () {
        _changeQuantity(item, item.quantity - 1);
      },
      onIncrease: () {
        _changeQuantity(item, item.quantity + 1);
      },
    );
  }

  Widget _buildUnavailableNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4ED),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFF2D2BE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _danger, size: 18),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              '$_unavailableCount ${_unavailableCount == 1 ? 'item is' : 'items are'} unavailable or on seller vacation and cannot be selected for checkout.',
              style: const TextStyle(
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
    final DeliveryAddressData? address = widget.defaultAddress;

    return _SectionCard(
      title: 'Delivery Address',
      subtitle:
          'Preview your saved address. You can still confirm or change it during checkout.',
      trailing: TextButton(
        onPressed: widget.onChangeAddress,
        child: Text(
          address == null ? 'Add' : 'Change',
          style: const TextStyle(
            color: _maroon,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: address == null
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0D7B5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_off_outlined, color: _maroon, size: 21),

                  SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      'No default delivery address is saved. You can add or choose an address during checkout.',
                      style: TextStyle(
                        color: _text,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE7C6B7)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: ShopColors.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: _maroon,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              address.recipientName,
                              style: const TextStyle(
                                color: _text,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            if (address.contactNumber.trim().isNotEmpty)
                              Text(
                                address.contactNumber,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12.5,
                                ),
                              ),

                            if (address.isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: ShopColors.accentSoft,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: const Text(
                                  'DEFAULT',
                                  style: TextStyle(
                                    color: _maroon,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 7),

                        Text(
                          address.formattedAddress,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 13,
                            height: 1.45,
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
    final Map<String, dynamic>? quote = _serverQuote;
    final dynamic rawAvailability = quote?['delivery_availability'];
    final Map<String, dynamic>? availability = rawAvailability is Map
        ? Map<String, dynamic>.from(rawAvailability)
        : null;
    String amount(String key) {
      final dynamic raw = quote?[key];
      final double? value = raw is num
          ? raw.toDouble()
          : double.tryParse(raw?.toString() ?? '');
      return value == null ? '—' : 'PHP ${value.toStringAsFixed(2)}';
    }

    return _SectionCard(
      title: 'Cart Summary',
      subtitle: 'Only selected products will continue to checkout.',
      child: Column(
        children: [
          _SummaryRow(
            label: 'Selected products',
            value: '${_selectedItems.length}',
          ),

          const SizedBox(height: 11),

          _SummaryRow(label: 'Total quantity', value: '$_selectedQuantity'),

          const SizedBox(height: 15),

          if (quote != null) ...[
            const Divider(height: 1),
            const SizedBox(height: 13),
            _SummaryRow(label: 'Items subtotal', value: amount('subtotal')),
            const SizedBox(height: 9),
            _SummaryRow(
              label: 'Discounts',
              value: '- ${amount('total_discount')}',
            ),
            const SizedBox(height: 9),
            _SummaryRow(label: 'Delivery', value: amount('shipping_total')),
            if ((double.tryParse(
                      (quote['protection_total'] ?? '0').toString(),
                    ) ??
                    0) >
                0) ...[
              const SizedBox(height: 9),
              _SummaryRow(
                label: 'Additional Care',
                value: amount('protection_total'),
              ),
            ],
            const SizedBox(height: 11),
            _SummaryRow(label: 'Estimated total', value: amount('grand_total')),
            if (availability != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  availability['available'] == true
                      ? (availability['message']?.toString() ??
                            'Delivery is available for this address.')
                      : (availability['message']?.toString() ??
                            'Delivery availability needs attention.'),
                  style: TextStyle(
                    color: availability['available'] == true ? _muted : _danger,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ] else if (_loadingQuote) ...[
            const Row(
              children: <Widget>[
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 9),
                Text(
                  'Getting an updated total…',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else if (_quoteError != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _scheduleCartQuote,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('Retry price preview: $_quoteError'),
              ),
            ),
          ] else if (_selectedItems.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose or update a saved delivery address to see the delivery estimate and total.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Text(
              'This estimate comes from the server. Checkout refreshes stock, delivery, vouchers, and the final total before you place the order.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomEditBar() {
    final bool allSelected =
        _items.isNotEmpty && _deleteSelectedIds.length == _items.length;
    final bool someSelected = _deleteSelectedIds.isNotEmpty && !allSelected;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: _surface,
          border: const Border(top: BorderSide(color: _border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Checkbox(
              tristate: true,
              value: allSelected
                  ? true
                  : someSelected
                  ? null
                  : false,
              activeColor: _maroon,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (_) => _toggleAllForRemoval(),
            ),
            GestureDetector(
              onTap: _toggleAllForRemoval,
              child: const Text(
                'All',
                style: TextStyle(
                  color: _text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${_deleteSelectedIds.length} selected',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _deleteSelectedIds.isEmpty || _removingSelected
                    ? null
                    : _removeEditSelectedItems,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _danger,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD8D2CB),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: _removingSelected
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Remove (${_deleteSelectedIds.length})',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCheckoutBar() {
    final bool canCheckout = _selectedItems.isNotEmpty;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: _surface,
          border: const Border(top: BorderSide(color: _border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMarketplaceVoucherRow(),
            const Divider(height: 1, color: _border),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  tristate: true,
                  value: _allSelected
                      ? true
                      : _someSelected
                      ? null
                      : false,
                  activeColor: _maroon,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: _availableItems.isEmpty
                      ? null
                      : (_) => _toggleSelectAll(),
                ),
                GestureDetector(
                  onTap: _availableItems.isEmpty ? null : _toggleSelectAll,
                  child: const Text(
                    'All',
                    style: TextStyle(
                      color: _text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_shopVoucherDiscount > 0)
                      Text(
                        'Voucher −${_formatCartAmount(_shopVoucherDiscount)}',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFF19734A),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Text(
                      _formatCartAmount(
                        (_subtotal - _shopVoucherDiscount)
                            .clamp(0, _subtotal)
                            .toDouble(),
                      ),
                      maxLines: 1,
                      style: const TextStyle(
                        color: ShopColors.accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: !canCheckout || _openingCheckout
                        ? null
                        : _openCheckout,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _maroon,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD8D2CB),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: _openingCheckout
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Checkout (${_selectedItems.length})',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketplaceVoucherRow() {
    final int selectedVoucherCount =
        _selectedVoucherCodes.length +
        (_selectedPlatformVoucherCode?.isNotEmpty == true ? 1 : 0) +
        (_selectedShippingVoucherCode?.isNotEmpty == true ? 1 : 0);
    final String label = selectedVoucherCount == 0
        ? 'Select or enter a code'
        : '$selectedVoucherCount voucher${selectedVoucherCount == 1 ? '' : 's'} selected';
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: _selectedItems.isEmpty || _openingVoucherPicker
            ? null
            : () => _openVoucherPicker(),
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              const Icon(
                Icons.confirmation_number_outlined,
                color: _maroon,
                size: 21,
              ),
              const SizedBox(width: 10),
              const Text(
                'LIKHAE Vouchers',
                style: TextStyle(
                  color: _text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_openingVoucherPicker)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _maroon,
                  ),
                )
              else
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: _muted, fontSize: 12.5),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: ShopColors.faint,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItemData item;

  final bool selected;
  final bool editMode;
  final bool updating;
  final bool removing;

  final VoidCallback onSelectionChanged;

  final VoidCallback onProductTap;

  final VoidCallback onRemove;

  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _CartItemCard({
    required this.item,
    required this.selected,
    required this.editMode,
    required this.updating,
    required this.removing,
    required this.onSelectionChanged,
    required this.onProductTap,
    required this.onRemove,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final bool unavailable = !item.isAvailable;

    return AnimatedOpacity(
      opacity: removing ? 0.55 : 1,
      duration: const Duration(milliseconds: 160),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
        color: unavailable ? const Color(0xFFFFFBF8) : ShopColors.surface,
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selected,
                  activeColor: ShopColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: removing || (unavailable && !editMode)
                      ? null
                      : (_) {
                          onSelectionChanged();
                        },
                ),

                GestureDetector(
                  onTap: onProductTap,
                  child: Stack(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: ShopColors.soft,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: ShopColors.border),
                        ),
                        child: _CartProductImage(imageUrl: item.imageUrl),
                      ),

                      if (unavailable)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              item.sellerOnVacation
                                  ? 'SELLER ON\nVACATION'
                                  : 'UNAVAILABLE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: onProductTap,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.category.trim().isNotEmpty) ...[
                                    Text(
                                      item.category.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: ShopColors.accent,
                                        fontSize: 10,
                                        letterSpacing: 0.7,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),

                                    const SizedBox(height: 4),
                                  ],

                                  Text(
                                    item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: ShopColors.text,
                                      fontSize: 14,
                                      height: 1.25,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (!editMode) ...[
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: 'Remove item',
                                onPressed: removing ? null : onRemove,
                                icon: removing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFB42318),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFB42318),
                                        size: 18,
                                      ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (item.variant.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),

                        Text(
                          'Variant: ${item.variant}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ShopColors.faint,
                            fontSize: 12,
                          ),
                        ),
                      ],

                      if (unavailable) ...[
                        const SizedBox(height: 5),

                        const Text(
                          'Currently unavailable',
                          style: TextStyle(
                            color: Color(0xFFB42318),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _formatCartAmount(item.price),
                            style: const TextStyle(
                              color: ShopColors.accent,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          if (item.oldPrice != null &&
                              item.oldPrice! > item.price)
                            Text(
                              _formatCartAmount(item.oldPrice!),
                              style: const TextStyle(
                                color: ShopColors.faint,
                                fontSize: 11.5,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 3),

                      Text(
                        unavailable
                            ? 'Out of stock'
                            : '${item.stock} available',
                        style: TextStyle(
                          color: unavailable
                              ? const Color(0xFFB42318)
                              : ShopColors.faint,
                          fontSize: 11.5,
                          fontWeight: unavailable
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                _QuantityControl(
                  quantity: item.quantity,
                  canDecrease: item.isAvailable && item.quantity > 1,
                  canIncrease: item.isAvailable && item.quantity < item.stock,
                  loading: updating,
                  onDecrease: onDecrease,
                  onIncrease: onIncrease,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: Text(
                    _formatCartAmount(item.lineTotal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: ShopColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSellerGroup {
  final String name;
  final List<CartItemData> items = <CartItemData>[];

  int? get sellerId {
    for (final CartItemData item in items) {
      final int? id = item.sellerId;
      if (id != null && id > 0) return id;
    }
    return null;
  }

  _CartSellerGroup({required this.name});
}

class _QuantityControl extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDBCEC1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _quantityButton(
            icon: Icons.remove_rounded,
            enabled: canDecrease && !loading,
            onTap: onDecrease,
          ),

          Container(
            width: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: ShopColors.border),
                right: BorderSide(color: ShopColors.border),
              ),
            ),
            child: loading
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ShopColors.accent,
                    ),
                  )
                : Text(
                    '$quantity',
                    style: const TextStyle(
                      color: ShopColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),

          _quantityButton(
            icon: Icons.add_rounded,
            enabled: canIncrease && !loading,
            onTap: onIncrease,
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
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(
          icon,
          size: 15,
          color: enabled ? ShopColors.accent : const Color(0xFFC9C2BA),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ShopColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 10, 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: ShopColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: ShopColors.muted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                ?trailing,
              ],
            ),
          ),

          const Divider(color: ShopColors.border, height: 1),

          Padding(padding: const EdgeInsets.all(15), child: child),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: ShopColors.muted, fontSize: 13),
          ),
        ),

        Text(
          value,
          style: const TextStyle(
            color: ShopColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CartProductImage extends StatelessWidget {
  final String? imageUrl;
  const _CartProductImage({required this.imageUrl});
  @override
  Widget build(BuildContext context) {
    final value = imageUrl?.trim() ?? '';
    if (value.isEmpty)
      return const Center(
        child: Icon(Icons.image_outlined, color: ShopColors.faint, size: 31),
      );
    return SizedNetworkImage(
      url: AppConfig.resolveMediaUrl(value),
      iconSize: 31,
    );
  }
}
