import 'dart:math' as math;

import 'package:flutter/material.dart';

enum CheckoutPaymentMethod {
  cashOnDelivery,
  online,
}

extension CheckoutPaymentMethodInfo on CheckoutPaymentMethod {
  String get backendValue {
    switch (this) {
      case CheckoutPaymentMethod.cashOnDelivery:
        return 'cash_on_delivery';

      case CheckoutPaymentMethod.online:
        return 'online';
    }
  }

  String get title {
    switch (this) {
      case CheckoutPaymentMethod.cashOnDelivery:
        return 'Cash on Delivery';

      case CheckoutPaymentMethod.online:
        return 'Online Payment';
    }
  }

  String get description {
    switch (this) {
      case CheckoutPaymentMethod.cashOnDelivery:
        return 'Pay when your order arrives.';

      case CheckoutPaymentMethod.online:
        return 'Pay using an available online payment method.';
    }
  }

  IconData get icon {
    switch (this) {
      case CheckoutPaymentMethod.cashOnDelivery:
        return Icons.payments_outlined;

      case CheckoutPaymentMethod.online:
        return Icons.account_balance_wallet_outlined;
    }
  }
}

class CheckoutItemData {
  /// Cart-item ID for cart checkout.
  ///
  /// For direct Buy Now checkout, this can represent the
  /// direct checkout item identifier supplied by Laravel.
  final String id;

  /// Optional product context for future mobile API wiring.
  final int? productId;
  final int? productVariationId;

  final String? slug;

  final String name;
  final String variant;

  final String? imageUrl;

  final double price;

  final int quantity;

  const CheckoutItemData({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.productId,
    this.productVariationId,
    this.slug,
    this.variant = '',
    this.imageUrl,
  });

  int get safeQuantity {
    return math.max(
      1,
      quantity,
    );
  }

  double get lineTotal {
    return price * safeQuantity;
  }
}

class CheckoutVoucherData {
  final String code;

  final String campaignName;
  final String sellerName;

  final double discount;

  const CheckoutVoucherData({
    required this.code,
    required this.campaignName,
    required this.sellerName,
    required this.discount,
  });
}

class CheckoutRequestItem {
  final String id;

  final int quantity;

  final int? productId;
  final int? productVariationId;

  final String? variant;

  const CheckoutRequestItem({
    required this.id,
    required this.quantity,
    this.productId,
    this.productVariationId,
    this.variant,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'quantity': math.max(
        1,
        quantity,
      ),
      if (productId != null)
        'product_id': productId,
      if (productVariationId != null)
        'product_variation_id':
            productVariationId,
      if (variant != null &&
          variant!.trim().isNotEmpty)
        'variant': variant,
    };
  }
}

class CheckoutVoucherRequest {
  final String checkoutSource;

  final List<CheckoutRequestItem> items;

  final String voucherCode;

  const CheckoutVoucherRequest({
    required this.checkoutSource,
    required this.items,
    required this.voucherCode,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'checkout_source':
          checkoutSource,
      'items': items
          .map(
            (
              CheckoutRequestItem item,
            ) =>
                item.toMap(),
          )
          .toList(),
      'voucher_code':
          voucherCode,
    };
  }
}

class CheckoutVoucherResult {
  final CheckoutVoucherData? voucher;

  final String? errorMessage;

  const CheckoutVoucherResult({
    this.voucher,
    this.errorMessage,
  });

  factory CheckoutVoucherResult.success(
    CheckoutVoucherData voucher,
  ) {
    return CheckoutVoucherResult(
      voucher: voucher,
    );
  }

  factory CheckoutVoucherResult.failure(
    String message,
  ) {
    return CheckoutVoucherResult(
      errorMessage: message,
    );
  }
}

class CheckoutOrderRequest {
  final String checkoutSource;

  final List<CheckoutRequestItem> items;

  final String recipientName;
  final String contactNumber;
  final String deliveryAddress;

  final CheckoutPaymentMethod paymentMethod;

  /// Only the successfully applied voucher code is sent.
  final String voucherCode;

  const CheckoutOrderRequest({
    required this.checkoutSource,
    required this.items,
    required this.recipientName,
    required this.contactNumber,
    required this.deliveryAddress,
    required this.paymentMethod,
    this.voucherCode = '',
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'checkout_source':
          checkoutSource,
      'items': items
          .map(
            (
              CheckoutRequestItem item,
            ) =>
                item.toMap(),
          )
          .toList(),
      'voucher_code':
          voucherCode,
      'recipient_name':
          recipientName,
      'contact_number':
          contactNumber,
      'delivery_address':
          deliveryAddress,
      'payment_method':
          paymentMethod.backendValue,
    };
  }
}

typedef CheckoutApplyVoucherCallback =
    Future<CheckoutVoucherResult> Function(
  CheckoutVoucherRequest request,
);

typedef CheckoutPlaceOrderCallback =
    Future<void> Function(
  CheckoutOrderRequest request,
);

typedef CheckoutRefreshCallback =
    Future<void> Function();

class CheckoutScreen extends StatefulWidget {
  final List<CheckoutItemData> items;

  /// Matches Laravel's checkout_source.
  ///
  /// Expected values:
  /// cart
  /// direct
  final String checkoutSource;

  final String initialRecipientName;
  final String initialContactNumber;
  final String initialDeliveryAddress;

  final CheckoutPaymentMethod
      initialPaymentMethod;

  /// Laravel currently initializes this as 0 in the Blade,
  /// but keeping it configurable means the UI does not need
  /// another redesign once shipping calculation is connected.
  final double deliveryFee;

  final CheckoutVoucherData?
      voucher;

  final String? voucherError;

  /// Optional initial voucher input.
  final String initialVoucherCode;

  final VoidCallback? onBack;

  /// Alias for explicit Cart navigation.
  final VoidCallback? onBackToCart;

  final CheckoutApplyVoucherCallback?
      onApplyVoucher;

  /// This callback represents the real Place Order action.
  ///
  /// The screen never pretends an order succeeded when this
  /// callback is absent.
  final CheckoutPlaceOrderCallback?
      onPlaceOrder;

  final CheckoutRefreshCallback?
      onRefresh;

  const CheckoutScreen({
    super.key,
    this.items =
        const <CheckoutItemData>[],
    this.checkoutSource = 'cart',
    this.initialRecipientName = '',
    this.initialContactNumber = '',
    this.initialDeliveryAddress = '',
    this.initialPaymentMethod =
        CheckoutPaymentMethod
            .cashOnDelivery,
    this.deliveryFee = 0,
    this.voucher,
    this.voucherError,
    this.initialVoucherCode = '',
    this.onBack,
    this.onBackToCart,
    this.onApplyVoucher,
    this.onPlaceOrder,
    this.onRefresh,
  });

  @override
  State<CheckoutScreen> createState() =>
      _CheckoutScreenState();
}

class _CheckoutScreenState
    extends State<CheckoutScreen> {
  static const Color _background =
      Color(0xFFFBF7F2);

  static const Color _surface =
      Color(0xFFFFFDF9);

  static const Color _softStrong =
      Color(0xFFF1E4D7);

  static const Color _border =
      Color(0xFFEADCCC);

  static const Color _maroon =
      Color(0xFF561C17);

  static const Color _maroonDark =
      Color(0xFF3E130F);

  static const Color _text =
      Color(0xFF3B211B);

  static const Color _brown =
      Color(0xFF6C4936);

  static const Color _muted =
      Color(0xFF987865);

  static const Color _success =
      Color(0xFF1B7A46);

  static const Color _tan =
      Color(0xFFC19771);

  static const Color _danger =
      Color(0xFFB42318);

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController
      _recipientController;

  late final TextEditingController
      _contactController;

  late final TextEditingController
      _addressController;

  late final TextEditingController
      _voucherController;

  late CheckoutPaymentMethod
      _paymentMethod;

  CheckoutVoucherData?
      _appliedVoucher;

  String? _voucherError;

  bool _applyingVoucher = false;
  bool _placingOrder = false;

  @override
  void initState() {
    super.initState();

    _recipientController =
        TextEditingController(
      text:
          widget.initialRecipientName,
    );

    _contactController =
        TextEditingController(
      text:
          widget.initialContactNumber,
    );

    _addressController =
        TextEditingController(
      text:
          widget.initialDeliveryAddress,
    );

    final String initialCode =
        widget.voucher?.code ??
            widget.initialVoucherCode;

    _voucherController =
        TextEditingController(
      text: initialCode,
    );

    _paymentMethod =
        widget.initialPaymentMethod;

    _appliedVoucher =
        widget.voucher;

    _voucherError =
        widget.voucherError;
  }

  @override
  void didUpdateWidget(
    covariant CheckoutScreen oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.voucher !=
        widget.voucher) {
      _appliedVoucher =
          widget.voucher;

      final String? code =
          widget.voucher?.code;

      if (code != null &&
          code.trim().isNotEmpty) {
        _voucherController.text =
            code;
      }
    }

    if (oldWidget.voucherError !=
        widget.voucherError) {
      _voucherError =
          widget.voucherError;
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();

    _contactController.dispose();

    _addressController.dispose();

    _voucherController.dispose();

    super.dispose();
  }

  String get _checkoutSource {
    return widget.checkoutSource
                .trim()
                .toLowerCase() ==
            'direct'
        ? 'direct'
        : 'cart';
  }

  List<CheckoutRequestItem>
      get _requestItems {
    return widget.items
        .map(
          (
            CheckoutItemData item,
          ) =>
              CheckoutRequestItem(
            id: item.id,
            quantity:
                item.safeQuantity,
            productId:
                item.productId,
            productVariationId:
                item.productVariationId,
            variant:
                item.variant,
          ),
        )
        .toList();
  }

  double get _productTotal {
    return widget.items
        .fold<double>(
      0,
      (
        double total,
        CheckoutItemData item,
      ) =>
          total + item.lineTotal,
    );
  }

  double get _deliveryFee {
    return math.max(
      0,
      widget.deliveryFee,
    );
  }

  double get _voucherDiscount {
    final double discount =
        math.max(
      0,
      _appliedVoucher?.discount ?? 0,
    );

    return math.min(
      discount,
      _productTotal,
    );
  }

  double get _total {
    return math.max(
      0,
      _productTotal +
          _deliveryFee -
          _voucherDiscount,
    );
  }

  Future<void> _applyVoucher() async {
    if (_applyingVoucher ||
        _placingOrder) {
      return;
    }

    final String code =
        _voucherController.text
            .trim()
            .toUpperCase();

    if (code.isEmpty) {
      setState(() {
        _voucherError =
            'Enter a voucher code.';
      });

      return;
    }

    if (code.length > 40) {
      setState(() {
        _voucherError =
            'Voucher code must not exceed 40 characters.';
      });

      return;
    }

    final CheckoutApplyVoucherCallback?
        callback =
        widget.onApplyVoucher;

    if (callback == null) {
      _showMessage(
        'Voucher validation will be connected to Laravel later.',
      );

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _applyingVoucher = true;
      _voucherError = null;
    });

    try {
      final CheckoutVoucherResult
          result =
          await callback(
        CheckoutVoucherRequest(
          checkoutSource:
              _checkoutSource,
          items:
              _requestItems,
          voucherCode:
              code,
        ),
      );

      if (!mounted) {
        return;
      }

      final CheckoutVoucherData?
          voucher =
          result.voucher;

      if (voucher != null) {
        setState(() {
          _appliedVoucher =
              voucher;

          _voucherError = null;

          _voucherController.text =
              voucher.code;
        });
      } else {
        setState(() {
          _appliedVoucher = null;

          _voucherError =
              result.errorMessage ??
                  'Voucher could not be applied.';
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _voucherError =
            _errorText(
          error,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _applyingVoucher =
              false;
        });
      }
    }
  }

  void _clearVoucher() {
    if (_applyingVoucher ||
        _placingOrder) {
      return;
    }

    setState(() {
      _appliedVoucher = null;
      _voucherError = null;

      _voucherController.clear();
    });
  }

  Future<void> _placeOrder() async {
    if (_placingOrder ||
        _applyingVoucher) {
      return;
    }

    if (widget.items.isEmpty) {
      _showMessage(
        'Add a product before placing an order.',
        error: true,
      );

      return;
    }

    final FormState? form =
        _formKey.currentState;

    if (form == null ||
        !form.validate()) {
      _showMessage(
        'Complete the required checkout details.',
        error: true,
      );

      return;
    }

    final CheckoutPlaceOrderCallback?
        callback =
        widget.onPlaceOrder;

    if (callback == null) {
      _showMessage(
        'Place Order will be connected to Laravel later.',
      );

      return;
    }

    FocusScope.of(context).unfocus();

    final CheckoutOrderRequest request =
        CheckoutOrderRequest(
      checkoutSource:
          _checkoutSource,
      items:
          _requestItems,
      recipientName:
          _recipientController.text
              .trim(),
      contactNumber:
          _contactController.text
              .trim(),
      deliveryAddress:
          _addressController.text
              .trim(),
      paymentMethod:
          _paymentMethod,
      voucherCode:
          _appliedVoucher?.code ??
              '',
    );

    setState(() {
      _placingOrder = true;
    });

    try {
      /*
       * Completion of this callback means Laravel accepted
       * the order operation.
       *
       * Navigation to order-success/orders should normally be
       * handled by the parent callback.
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
          _placingOrder = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    final CheckoutRefreshCallback?
        callback =
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

  void _goBack() {
    final VoidCallback? callback =
        widget.onBackToCart ??
            widget.onBack;

    if (callback != null) {
      callback();
      return;
    }

    Navigator.of(
      context,
    ).maybePop();
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
                    widget.items.isEmpty
                        ? _buildEmptyCheckout()
                        : _buildCheckout(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        7,
        5,
        10,
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
            tooltip:
                _checkoutSource ==
                        'cart'
                    ? 'Back to Cart'
                    : 'Back',
            onPressed:
                _goBack,
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

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Checkout',
                  style:
                      TextStyle(
                    color: _text,
                    fontSize: 19,
                    height: 1.1,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing:
                        -0.4,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  _checkoutSource ==
                          'direct'
                      ? 'Buy Now checkout'
                      : 'Cart checkout',
                  style:
                      const TextStyle(
                    color: _muted,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration:
                BoxDecoration(
              color:
                  _softStrong,
              borderRadius:
                  BorderRadius.circular(
                100,
              ),
            ),
            child:
                const Row(
              children: [
                Icon(
                  Icons
                      .lock_outline_rounded,
                  color: _maroon,
                  size: 13,
                ),

                SizedBox(
                  width: 4,
                ),

                Text(
                  'SECURE',
                  style:
                      TextStyle(
                    color: _maroon,
                    fontSize: 7.5,
                    letterSpacing:
                        0.6,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCheckout() {
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
                  _softStrong,
              shape:
                  BoxShape.circle,
            ),
            alignment:
                Alignment.center,
            child:
                const Icon(
              Icons
                  .shopping_bag_outlined,
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
            fontSize: 21,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        const Text(
          'Add a product before checking out.',
          textAlign:
              TextAlign.center,
          style:
              TextStyle(
            color: _muted,
            fontSize: 12,
            height: 1.55,
          ),
        ),

        const SizedBox(
          height: 24,
        ),

        Center(
          child:
              OutlinedButton.icon(
            onPressed:
                _goBack,
            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  _maroon,
              side:
                  const BorderSide(
                color: _tan,
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 13,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
            ),
            icon:
                const Icon(
              Icons
                  .arrow_back_rounded,
              size: 17,
            ),
            label:
                Text(
              _checkoutSource ==
                      'cart'
                  ? 'Back to Cart'
                  : 'Go Back',
              style:
                  const TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckout() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        14,
        16,
        14,
        110,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1120,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildPageHeading(),

                const SizedBox(
                  height: 18,
                ),

                _buildVoucherSection(),

                const SizedBox(
                  height: 16,
                ),

                Form(
                  key: _formKey,
                  child:
                      LayoutBuilder(
                    builder: (
                      BuildContext context,
                      BoxConstraints constraints,
                    ) {
                      final bool wide =
                          constraints.maxWidth >=
                              820;

                      if (wide) {
                        return Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child:
                                  _buildDetailsColumn(),
                            ),

                            const SizedBox(
                              width: 16,
                            ),

                            SizedBox(
                              width: 340,
                              child:
                                  _buildOrderSummary(),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          _buildDetailsColumn(),

                          const SizedBox(
                            height: 16,
                          ),

                          _buildOrderSummary(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageHeading() {
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
                'SECURE CHECKOUT',
                style:
                    TextStyle(
                  color: _maroon,
                  fontSize: 8.5,
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
                'Review and place your order',
                style:
                    TextStyle(
                  color: _text,
                  fontSize: 27,
                  height: 1.05,
                  letterSpacing:
                      -0.7,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              SizedBox(
                height: 7,
              ),

              Text(
                'Confirm recipient details, delivery address, and payment method.',
                style:
                    TextStyle(
                  color: _muted,
                  fontSize: 10.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        if (_checkoutSource ==
            'cart')
          TextButton.icon(
            onPressed:
                _goBack,
            icon:
                const Icon(
              Icons
                  .arrow_back_rounded,
              size: 14,
            ),
            label:
                const Text(
              'Cart',
            ),
            style:
                TextButton.styleFrom(
              foregroundColor:
                  _brown,
              textStyle:
                  const TextStyle(
                fontSize: 10.5,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVoucherSection() {
    final CheckoutVoucherData?
        voucher =
        _appliedVoucher;

    return _CheckoutSection(
      title:
          'Seller voucher',
      subtitle:
          'Enter a voucher code created by the seller. It applies only to that seller\'s products.',
      icon:
          Icons
              .confirmation_number_outlined,
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
                    TextField(
                  controller:
                      _voucherController,
                  enabled:
                      !_applyingVoucher &&
                          !_placingOrder,
                  textCapitalization:
                      TextCapitalization.characters,
                  maxLength:
                      40,
                  decoration:
                      InputDecoration(
                    hintText:
                        'Enter voucher code',
                    counterText:
                        '',
                    prefixIcon:
                        const Icon(
                      Icons
                          .local_offer_outlined,
                      color:
                          _muted,
                      size: 19,
                    ),
                    filled:
                        true,
                    fillColor:
                        _surface,
                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal:
                          12,
                      vertical:
                          13,
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                      borderSide:
                          const BorderSide(
                        color:
                            _border,
                      ),
                    ),
                    enabledBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                      borderSide:
                          const BorderSide(
                        color:
                            _border,
                      ),
                    ),
                    focusedBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                      borderSide:
                          const BorderSide(
                        color:
                            _maroon,
                        width:
                            1.3,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              SizedBox(
                height: 49,
                child:
                    OutlinedButton(
                  onPressed:
                      _applyingVoucher ||
                              _placingOrder
                          ? null
                          : _applyVoucher,
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        _maroon,
                    side:
                        const BorderSide(
                      color:
                          _tan,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  child:
                      _applyingVoucher
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                                color:
                                    _maroon,
                              ),
                            )
                          : const Text(
                              'Apply',
                              style:
                                  TextStyle(
                                fontSize:
                                    10.5,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                ),
              ),
            ],
          ),

          if (voucher != null) ...[
            const SizedBox(
              height: 12,
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
                color:
                    const Color(
                  0xFFEEF8F1,
                ),
                borderRadius:
                    BorderRadius.circular(
                  11,
                ),
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFFCBE4D3,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons
                        .check_circle_outline_rounded,
                    color:
                        _success,
                    size: 18,
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${voucher.campaignName} from ${voucher.sellerName} applied.',
                          style:
                              const TextStyle(
                            color:
                                _success,
                            fontSize:
                                9.5,
                            height:
                                1.4,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),

                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          'You save ${_formatPrice(_voucherDiscount)}.',
                          style:
                              const TextStyle(
                            color:
                                _success,
                            fontSize:
                                9,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    tooltip:
                        'Remove voucher',
                    onPressed:
                        _clearVoucher,
                    icon:
                        const Icon(
                      Icons
                          .close_rounded,
                      color:
                          _success,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_voucherError !=
              null) ...[
            const SizedBox(
              height: 10,
            ),

            Text(
              _voucherError!,
              style:
                  const TextStyle(
                color: _danger,
                fontSize: 9.5,
                height: 1.4,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsColumn() {
    return Column(
      children: [
        _buildRecipientSection(),

        const SizedBox(
          height: 16,
        ),

        _buildDeliveryAddressSection(),

        const SizedBox(
          height: 16,
        ),

        _buildPaymentMethodSection(),
      ],
    );
  }

  Widget _buildRecipientSection() {
    return _CheckoutSection(
      title:
          'Recipient',
      subtitle:
          'Confirm who will receive this order.',
      icon:
          Icons
              .person_outline_rounded,
      child: LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          final bool split =
              constraints.maxWidth >=
                  520;

          final Widget nameField =
              _CheckoutTextField(
            controller:
                _recipientController,
            label:
                'Full name',
            hint:
                'Recipient full name',
            textInputAction:
                split
                    ? TextInputAction.next
                    : TextInputAction.next,
            validator:
                _requiredValidator(
              'Full name',
            ),
          );

          final Widget contactField =
              _CheckoutTextField(
            controller:
                _contactController,
            label:
                'Contact number',
            hint:
                'Contact number',
            keyboardType:
                TextInputType.phone,
            textInputAction:
                TextInputAction.next,
            validator:
                _requiredValidator(
              'Contact number',
            ),
          );

          if (split) {
            return Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child:
                      nameField,
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child:
                      contactField,
                ),
              ],
            );
          }

          return Column(
            children: [
              nameField,

              const SizedBox(
                height: 12,
              ),

              contactField,
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeliveryAddressSection() {
    return _CheckoutSection(
      title:
          'Delivery address',
      subtitle:
          'Confirm the complete address where the order should be delivered.',
      icon:
          Icons
              .location_on_outlined,
      child:
          _CheckoutTextField(
        controller:
            _addressController,
        label:
            'Address',
        hint:
            'House number, street, barangay, municipality, province, postal code',
        maxLines:
            4,
        minLines:
            3,
        textInputAction:
            TextInputAction.newline,
        validator:
            _requiredValidator(
          'Delivery address',
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return _CheckoutSection(
      title:
          'Payment method',
      subtitle:
          'Choose how you want to pay for this order.',
      icon:
          Icons
              .account_balance_wallet_outlined,
      child: Column(
        children:
            CheckoutPaymentMethod.values
                .map(
          (
            CheckoutPaymentMethod method,
          ) {
            final bool selected =
                method ==
                    _paymentMethod;

            return Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 9,
              ),
              child:
                  _PaymentMethodTile(
                method:
                    method,
                selected:
                    selected,
                enabled:
                    !_placingOrder,
                onTap:
                    () {
                  setState(() {
                    _paymentMethod =
                        method;
                  });
                },
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return _CheckoutSection(
      title:
          'Order summary',
      subtitle:
          '${widget.items.length} ${widget.items.length == 1 ? 'product' : 'products'} in this checkout.',
      icon:
          Icons
              .receipt_long_outlined,
      child: Column(
        children: [
          for (int index = 0;
              index <
                  widget.items.length;
              index++) ...[
            _CheckoutItemRow(
              item:
                  widget.items[index],
            ),

            if (index !=
                widget.items.length -
                    1)
              const Padding(
                padding:
                    EdgeInsets.symmetric(
                  vertical: 11,
                ),
                child:
                    Divider(
                  color:
                      Color(
                    0xFFF0E8DF,
                  ),
                  height: 1,
                ),
              ),
          ],

          const SizedBox(
            height: 18,
          ),

          const Divider(
            color:
                Color(
              0xFFF0E8DF,
            ),
            height: 1,
          ),

          const SizedBox(
            height: 16,
          ),

          _SummaryRow(
            label:
                'Product total',
            value:
                _formatPrice(
              _productTotal,
            ),
          ),

          if (_voucherDiscount >
              0) ...[
            const SizedBox(
              height: 10,
            ),

            _SummaryRow(
              label:
                  'Seller voucher',
              value:
                  '-${_formatPrice(_voucherDiscount)}',
              valueColor:
                  _success,
            ),
          ],

          const SizedBox(
            height: 10,
          ),

          _SummaryRow(
            label:
                'Delivery fee',
            value:
                _formatPrice(
              _deliveryFee,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          const Divider(
            color:
                Color(
              0xFFF0E8DF,
            ),
            height: 1,
          ),

          const SizedBox(
            height: 16,
          ),

          Row(
            children: [
              const Expanded(
                child:
                    Text(
                  'Total',
                  style:
                      TextStyle(
                    color:
                        _text,
                    fontSize:
                        13,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              Text(
                _formatPrice(
                  _total,
                ),
                style:
                    const TextStyle(
                  color:
                      _maroon,
                  fontSize:
                      21,
                  letterSpacing:
                      -0.4,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          SizedBox(
            width:
                double.infinity,
            height: 50,
            child:
                ElevatedButton(
              onPressed:
                  _placingOrder ||
                          _applyingVoucher
                      ? null
                      : _placeOrder,
              style:
                  ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor:
                    _maroon,
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    _maroon.withValues(
                  alpha: 0.42,
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
                  _placingOrder
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons
                                  .lock_outline_rounded,
                              size:
                                  16,
                            ),

                            SizedBox(
                              width:
                                  7,
                            ),

                            Text(
                              'Place Order',
                              style:
                                  TextStyle(
                                fontSize:
                                    11.5,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          const Text(
            'Your order is created only after the Place Order request is accepted by the server.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color: _muted,
              fontSize: 8.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String? Function(String?)
      _requiredValidator(
    String fieldName,
  ) {
    return (
      String? value,
    ) {
      if (value == null ||
          value.trim().isEmpty) {
        return '$fieldName is required.';
      }

      return null;
    };
  }

  static String _formatPrice(
    double value,
  ) {
    return '₱${value.toStringAsFixed(2)}';
  }
}

class _CheckoutSection
    extends StatelessWidget {
  final String title;
  final String subtitle;

  final IconData icon;

  final Widget child;

  const _CheckoutSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
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
        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withValues(
              alpha: 0.025,
            ),
            blurRadius: 14,
            offset:
                const Offset(
              0,
              5,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 39,
                height: 39,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFF1E4D7,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                alignment:
                    Alignment.center,
                child:
                    Icon(
                  icon,
                  color:
                      const Color(
                    0xFF561C17,
                  ),
                  size: 18,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

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
                            13,
                        fontWeight:
                            FontWeight.w900,
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
                            9,
                        height:
                            1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          child,
        ],
      ),
    );
  }
}

class _CheckoutTextField
    extends StatelessWidget {
  final TextEditingController controller;

  final String label;
  final String hint;

  final TextInputType keyboardType;

  final TextInputAction textInputAction;

  final int maxLines;
  final int? minLines;

  final String? Function(String?)?
      validator;

  const _CheckoutTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.textInputAction,
    this.keyboardType =
        TextInputType.text,
    this.maxLines = 1,
    this.minLines,
    this.validator,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              const TextStyle(
            color:
                Color(
              0xFF3B211B,
            ),
            fontSize: 9.5,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        const SizedBox(
          height: 7,
        ),

        TextFormField(
          controller:
              controller,
          keyboardType:
              keyboardType,
          textInputAction:
              textInputAction,
          maxLines:
              maxLines,
          minLines:
              minLines,
          validator:
              validator,
          autovalidateMode:
              AutovalidateMode
                  .onUserInteraction,
          style:
              const TextStyle(
            color:
                Color(
              0xFF3B211B,
            ),
            fontSize: 11,
          ),
          decoration:
              InputDecoration(
            hintText:
                hint,
            hintStyle:
                const TextStyle(
              color:
                  Color(
                0xFFA99386,
              ),
              fontSize: 10,
            ),
            filled:
                true,
            fillColor:
                Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Color(
                  0xFFEADCCC,
                ),
              ),
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Color(
                  0xFFEADCCC,
                ),
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Color(
                  0xFF561C17,
                ),
                width: 1.3,
              ),
            ),
            errorBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Color(
                  0xFFB42318,
                ),
              ),
            ),
            focusedErrorBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Color(
                  0xFFB42318,
                ),
                width: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodTile
    extends StatelessWidget {
  final CheckoutPaymentMethod method;

  final bool selected;
  final bool enabled;

  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          selected
              ? const Color(
                  0xFFFFF2EE,
                )
              : const Color(
                  0xFFFFFDF9,
                ),
      borderRadius:
          BorderRadius.circular(
        13,
      ),
      child: InkWell(
        onTap:
            enabled
                ? onTap
                : null,
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        child: Container(
          padding:
              const EdgeInsets.all(
            12,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              13,
            ),
            border:
                Border.all(
              color:
                  selected
                      ? const Color(
                          0xFF561C17,
                        )
                      : const Color(
                          0xFFEADCCC,
                        ),
              width:
                  selected
                      ? 1.4
                      : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration:
                    BoxDecoration(
                  color:
                      selected
                          ? const Color(
                              0xFFF1E4D7,
                            )
                          : const Color(
                              0xFFF6EFE7,
                            ),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                alignment:
                    Alignment.center,
                child:
                    Icon(
                  method.icon,
                  color:
                      const Color(
                    0xFF561C17,
                  ),
                  size: 19,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.title,
                      style:
                          TextStyle(
                        color:
                            selected
                                ? const Color(
                                    0xFF561C17,
                                  )
                                : const Color(
                                    0xFF3B211B,
                                  ),
                        fontSize:
                            10.5,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      method.description,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF987865,
                        ),
                        fontSize:
                            8.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Icon(
                selected
                    ? Icons
                        .radio_button_checked_rounded
                    : Icons
                        .radio_button_off_rounded,
                color:
                    selected
                        ? const Color(
                            0xFF561C17,
                          )
                        : const Color(
                            0xFFA99386,
                          ),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutItemRow
    extends StatelessWidget {
  final CheckoutItemData item;

  const _CheckoutItemRow({
    required this.item,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
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
              10,
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
              _CheckoutProductImage(
            imageUrl:
                item.imageUrl,
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color:
                      Color(
                    0xFF3B211B,
                  ),
                  fontSize:
                      10,
                  height: 1.3,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                'Qty ${item.safeQuantity}',
                style:
                    const TextStyle(
                  color:
                      Color(
                    0xFF987865,
                  ),
                  fontSize:
                      8.5,
                ),
              ),

              if (item.variant
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(
                  height: 2,
                ),

                Text(
                  item.variant,
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
                        8,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        Text(
          '₱${item.lineTotal.toStringAsFixed(2)}',
          style:
              const TextStyle(
            color:
                Color(
              0xFF3B211B,
            ),
            fontSize: 10,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow
    extends StatelessWidget {
  final String label;
  final String value;

  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
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
                  10,
            ),
          ),
        ),

        Text(
          value,
          style:
              TextStyle(
            color:
                valueColor ??
                    const Color(
                      0xFF3B211B,
                    ),
            fontSize:
                10,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CheckoutProductImage
    extends StatelessWidget {
  final String? imageUrl;

  const _CheckoutProductImage({
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
              .inventory_2_outlined,
          color:
              Color(
            0xFFA99386,
          ),
          size: 24,
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (
        BuildContext context,
        Widget child,
        ImageChunkEvent? progress,
      ) {
        if (progress == null) {
          return child;
        }

        return const Center(
          child: SizedBox(
            width: 17,
            height: 17,
            child:
                CircularProgressIndicator(
              strokeWidth: 1.8,
              color:
                  Color(
                0xFF561C17,
              ),
            ),
          ),
        );
      },
      errorBuilder: (
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
            size: 24,
          ),
        );
      },
    );
  }
}