import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.checkoutToken,
    required this.items,
    required this.addresses,
    required this.couriersBySeller,
    this.appliedVoucherCodes = const <int, String>{},
    this.requireCourierSelection = true,
    this.defaultAddressId,
    this.initialRecipientName = '',
    this.initialContactNumber = '',
    this.onBackToCart,
    this.onPlaceOrder,
  });

  final String checkoutToken;
  final List<CheckoutItemData> items;
  final List<CheckoutAddressData> addresses;
  final Map<int, List<CheckoutCourierOption>> couriersBySeller;
  final Map<int, String> appliedVoucherCodes;
  final bool requireCourierSelection;
  final int? defaultAddressId;
  final String initialRecipientName;
  final String initialContactNumber;
  final VoidCallback? onBackToCart;
  final Future<void> Function(CheckoutPlaceOrderRequest request)? onPlaceOrder;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const Color _bg = Color(0xFFF6F6F6);
  static const Color _surface = Colors.white;
  static const Color _surfaceSoft = Color(0xFFFFF3EE);
  static const Color _border = Color(0xFFE8E8E8);
  static const Color _text = Color(0xFF292929);
  static const Color _muted = Color(0xFF7E7E7E);
  static const Color _primary = Color(0xFFE05A3F);
  static const Color _primaryDark = Color(0xFFB9432E);
  static const Color _danger = Color(0xFFB42318);
  static const Color _disabled = Color(0xFFD8CCC3);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _recipientController;
  late final TextEditingController _contactController;

  final Map<int, TextEditingController> _shopNoteControllers = {};
  final Map<int, int?> _selectedCouriers = {};
  final Set<int> _protectedProductIds = <int>{};

  int? _selectedAddressId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    _recipientController = TextEditingController(
      text: widget.initialRecipientName,
    );
    _contactController = TextEditingController(
      text: widget.initialContactNumber,
    );

    _selectedAddressId = _resolveInitialAddressId();
    _syncSelectedAddressFields();
    _syncShopState();
  }

  @override
  void didUpdateWidget(covariant CheckoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialRecipientName != widget.initialRecipientName) {
      _recipientController.text = widget.initialRecipientName;
    }

    if (oldWidget.initialContactNumber != widget.initialContactNumber) {
      _contactController.text = widget.initialContactNumber;
    }

    final bool stillExists = widget.addresses.any(
      (CheckoutAddressData address) => address.id == _selectedAddressId,
    );

    if (!stillExists) {
      _selectedAddressId = _resolveInitialAddressId();
    }

    _syncSelectedAddressFields();
    _syncShopState();
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _contactController.dispose();

    for (final TextEditingController controller
        in _shopNoteControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  int? _resolveInitialAddressId() {
    if (widget.addresses.isEmpty) {
      return null;
    }

    if (widget.defaultAddressId != null) {
      for (final CheckoutAddressData address in widget.addresses) {
        if (address.id == widget.defaultAddressId) {
          return address.id;
        }
      }
    }

    for (final CheckoutAddressData address in widget.addresses) {
      if (address.isDefault) {
        return address.id;
      }
    }

    return widget.addresses.first.id;
  }

  void _syncShopState() {
    final Set<int> sellerIds = widget.items
        .map((CheckoutItemData e) => e.sellerId)
        .toSet();

    for (final int sellerId in sellerIds) {
      _shopNoteControllers.putIfAbsent(sellerId, () => TextEditingController());

      _selectedCouriers.putIfAbsent(sellerId, () => null);

      final List<CheckoutCourierOption> options =
          widget.couriersBySeller[sellerId] ?? const <CheckoutCourierOption>[];

      final int? currentSelected = _selectedCouriers[sellerId];

      if (currentSelected != null &&
          !options.any(
            (CheckoutCourierOption item) => item.id == currentSelected,
          )) {
        _selectedCouriers[sellerId] = null;
      }
    }

    final List<int> toRemove = _shopNoteControllers.keys
        .where((int sellerId) => !sellerIds.contains(sellerId))
        .toList();

    for (final int sellerId in toRemove) {
      _shopNoteControllers.remove(sellerId)?.dispose();
      _selectedCouriers.remove(sellerId);
    }
  }

  Map<int, List<CheckoutItemData>> get _groupedItems {
    final Map<int, List<CheckoutItemData>> grouped =
        <int, List<CheckoutItemData>>{};

    for (final CheckoutItemData item in widget.items) {
      grouped.putIfAbsent(item.sellerId, () => <CheckoutItemData>[]).add(item);
    }

    return grouped;
  }

  CheckoutAddressData? get _selectedAddress {
    final int? id = _selectedAddressId;
    if (id == null) return null;

    for (final CheckoutAddressData address in widget.addresses) {
      if (address.id == id) return address;
    }
    return null;
  }

  void _syncSelectedAddressFields() {
    final CheckoutAddressData? address = _selectedAddress;
    if (address == null) return;

    if (_recipientController.text.trim().isEmpty &&
        address.recipient.trim().isNotEmpty) {
      _recipientController.text = address.recipient;
    }
    if (_contactController.text.trim().isEmpty &&
        address.phone.trim().isNotEmpty) {
      _contactController.text = address.phone;
    }
  }

  double get _productTotal {
    return widget.items.fold<double>(
      0,
      (double prev, CheckoutItemData item) => prev + item.lineTotal,
    );
  }

  double get _shippingTotal {
    double total = 0;

    for (final MapEntry<int, int?> entry in _selectedCouriers.entries) {
      final int? courierId = entry.value;
      if (courierId == null) continue;

      final List<CheckoutCourierOption> options =
          widget.couriersBySeller[entry.key] ?? const <CheckoutCourierOption>[];
      for (final CheckoutCourierOption option in options) {
        if (option.id == courierId) {
          total += option.fee;
          break;
        }
      }
    }

    return total;
  }

  double get _electronicProtectionTotal {
    double total = 0;
    for (final CheckoutItemData item in widget.items) {
      if (_protectedProductIds.contains(item.productId) &&
          item.isProtectionEligible) {
        total += _protectionFeeFor(item);
      }
    }
    return total;
  }

  double _protectionFeeFor(CheckoutItemData item) {
    // Six percent mirrors the protection amount shown in the checkout design.
    return (item.lineTotal * 0.06).roundToDouble();
  }

  double get _estimatedTotal =>
      _productTotal + _shippingTotal + _electronicProtectionTotal;

  bool get _hasMissingCourierAvailability {
    if (!widget.requireCourierSelection) {
      return false;
    }

    for (final int sellerId in _groupedItems.keys) {
      final List<CheckoutCourierOption> options =
          widget.couriersBySeller[sellerId] ?? const <CheckoutCourierOption>[];
      if (options.isEmpty) {
        return true;
      }
    }
    return false;
  }

  bool get _hasUnselectedCouriers {
    if (!widget.requireCourierSelection) {
      return false;
    }

    for (final int sellerId in _groupedItems.keys) {
      final List<CheckoutCourierOption> options =
          widget.couriersBySeller[sellerId] ?? const <CheckoutCourierOption>[];
      if (options.isNotEmpty && _selectedCouriers[sellerId] == null) {
        return true;
      }
    }
    return false;
  }

  bool get _canPlaceOrder {
    if (_submitting) return false;
    if (widget.items.isEmpty) return false;
    if (_selectedAddressId == null) return false;
    if (_recipientController.text.trim().isEmpty) return false;
    if (_contactController.text.trim().isEmpty) return false;
    if (_hasMissingCourierAvailability) return false;
    if (_hasUnselectedCouriers) return false;
    return true;
  }

  Future<void> _handlePlaceOrder() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAddressId == null) {
      _showSnack('Please choose a delivery address.');
      return;
    }

    if (_hasMissingCourierAvailability) {
      _showSnack('No approved courier is available for one or more shops.');
      return;
    }

    if (_hasUnselectedCouriers) {
      _showSnack('Please choose a courier for every shop.');
      return;
    }

    if (widget.onPlaceOrder == null) {
      _showSnack('Place Order is not connected to the Laravel API yet.');
      return;
    }

    final Map<int, int> couriers = <int, int>{};
    for (final MapEntry<int, int?> entry in _selectedCouriers.entries) {
      if (entry.value != null) {
        couriers[entry.key] = entry.value!;
      }
    }

    final Map<int, String> notes = <int, String>{};
    for (final MapEntry<int, TextEditingController> entry
        in _shopNoteControllers.entries) {
      final String note = entry.value.text.trim();
      if (note.isNotEmpty) {
        notes[entry.key] = note;
      }
    }

    final CheckoutPlaceOrderRequest request = CheckoutPlaceOrderRequest(
      checkoutToken: widget.checkoutToken,
      recipientName: _recipientController.text.trim(),
      contactNumber: _contactController.text.trim(),
      addressId: _selectedAddressId!,
      couriersBySeller: couriers,
      notesBySeller: notes,
      protectedProductIds: _protectedProductIds.toList(growable: false),
      paymentMethod: 'cod',
    );

    setState(() {
      _submitting = true;
    });

    try {
      await widget.onPlaceOrder!(request);
    } catch (error) {
      if (!mounted) return;
      _showSnack(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleBack() {
    if (widget.onBackToCart != null) {
      widget.onBackToCart!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  String _peso(double value) {
    final String fixed = value.toStringAsFixed(2);
    final List<String> parts = fixed.split('.');
    final String whole = parts.first;
    final String decimal = parts.last;

    final StringBuffer buffer = StringBuffer();
    for (int index = 0; index < whole.length; index++) {
      final int reverseIndex = whole.length - index;
      buffer.write(whole[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }

    return '₱${buffer.toString()}.$decimal';
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = widget.items.isEmpty;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 62,
        leadingWidth: 52,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: _handleBack,
          icon: const Icon(Icons.arrow_back_rounded, color: _primary),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(
            color: _text,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: const [SizedBox(width: 52)],
      ),
      body: isEmpty
          ? _buildEmptyState()
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wideLayout = constraints.maxWidth >= 980;

                if (wideLayout) {
                  return _buildWideLayout();
                }

                return _buildMobileLayout();
              },
            ),
      bottomNavigationBar: widget.items.isEmpty
          ? null
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wideLayout = MediaQuery.sizeOf(context).width >= 980;
                if (wideLayout) {
                  return const SizedBox.shrink();
                }
                return _buildBottomBar();
              },
            ),
    );
  }

  Widget _buildMobileLayout() {
    return SafeArea(
      bottom: false,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          children: [
            _buildMobileAddressCard(),
            const SizedBox(height: 8),
            ..._buildMobileSellerSections(),
            _buildMobileActionCard(),
            const SizedBox(height: 8),
            _buildMobilePaymentSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileAddressCard() {
    final CheckoutAddressData? address = _selectedAddress;

    if (address == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: _CheckoutCard(
          title: 'Delivery address',
          leadingIcon: Icons.location_on_outlined,
          child: _InfoBanner(
            icon: Icons.location_off_outlined,
            text: widget.addresses.isEmpty
                ? 'Add a delivery address before placing your order.'
                : 'Choose a delivery address before placing your order.',
            danger: true,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _showAddressPicker,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: _primary, size: 25),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              address.recipient.isEmpty
                                  ? _recipientController.text
                                  : address.recipient,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _text,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (address.phone.isNotEmpty)
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 9),
                                child: Text(
                                  address.phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        address.fullAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddressPicker() async {
    if (widget.addresses.isEmpty) return;

    final int? selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: widget.addresses.map((CheckoutAddressData address) {
              return ListTile(
                leading: Icon(
                  address.id == _selectedAddressId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: address.id == _selectedAddressId ? _primary : _muted,
                ),
                title: Text(
                  address.label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${address.recipient}\n${address.fullAddress}'),
                isThreeLine: true,
                onTap: () => Navigator.of(context).pop(address.id),
              );
            }).toList(),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      CheckoutAddressData? selectedAddress;
      for (final CheckoutAddressData address in widget.addresses) {
        if (address.id == selected) {
          selectedAddress = address;
          break;
        }
      }

      setState(() {
        _selectedAddressId = selected;
        if (selectedAddress != null) {
          _recipientController.text = selectedAddress.recipient;
          _contactController.text = selectedAddress.phone;
        }
      });
    }
  }

  List<Widget> _buildMobileSellerSections() {
    final List<Widget> sections = <Widget>[];

    for (final MapEntry<int, List<CheckoutItemData>> entry
        in _groupedItems.entries) {
      final int sellerId = entry.key;
      final List<CheckoutItemData> items = entry.value;
      final List<CheckoutCourierOption> options =
          widget.couriersBySeller[sellerId] ?? const <CheckoutCourierOption>[];

      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _CheckoutCard(
            title: items.first.seller,
            leadingIcon: Icons.storefront_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int index = 0; index < items.length; index++) ...[
                  _MobileCheckoutItem(item: items[index], peso: _peso),
                  if (items[index].isProtectionEligible)
                    _ElectronicProtectionTile(
                      selected: _protectedProductIds.contains(
                        items[index].productId,
                      ),
                      fee: _protectionFeeFor(items[index]),
                      onChanged: (bool selected) {
                        setState(() {
                          if (selected) {
                            _protectedProductIds.add(items[index].productId);
                          } else {
                            _protectedProductIds.remove(items[index].productId);
                          }
                        });
                      },
                    ),
                  if (index < items.length - 1)
                    const Divider(height: 22, color: _border),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Shipping Option',
                        style: TextStyle(
                          color: _text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      options.isEmpty ? 'Unavailable' : 'Choose one',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                if (options.isEmpty)
                  const _InfoBanner(
                    icon: Icons.local_shipping_outlined,
                    text: 'No approved courier currently serves this address.',
                    danger: true,
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCouriers[sellerId],
                    isExpanded: true,
                    decoration: _inputDecoration(
                      label: 'Delivery method',
                      hint: 'Select shipping option',
                    ),
                    items: options.map((CheckoutCourierOption option) {
                      return DropdownMenuItem<int>(
                        value: option.id,
                        child: Text(
                          '${option.name} · ${_peso(option.fee)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (int? value) {
                      setState(() {
                        _selectedCouriers[sellerId] = value;
                      });
                    },
                    validator: (int? value) {
                      if (widget.requireCourierSelection && value == null) {
                        return 'Please choose a shipping option.';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _shopNoteControllers[sellerId],
                  maxLength: 500,
                  maxLines: 1,
                  decoration: _inputDecoration(
                    label: 'Message for seller',
                    hint: 'Optional note',
                  ).copyWith(counterText: ''),
                ),
              ],
            ),
          ),
        ),
      );
      sections.add(const SizedBox(height: 8));
    }

    return sections;
  }

  Widget _buildMobileActionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _CheckoutCard(
        title: 'Order options',
        child: Column(
          children: [
            _CheckoutActionRow(
              icon: Icons.local_offer_outlined,
              label: 'Shop Voucher',
              value: widget.appliedVoucherCodes.isEmpty
                  ? 'Select or enter code'
                  : widget.appliedVoucherCodes.values.join(', '),
            ),
            const Divider(height: 22, color: _border),
            const _CheckoutActionRow(
              icon: Icons.receipt_long_outlined,
              label: 'E-receipt',
              value: 'Request later',
            ),
            const Divider(height: 22, color: _border),
            const _CheckoutActionRow(
              icon: Icons.payments_outlined,
              label: 'Payment method',
              value: 'Cash on Delivery',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobilePaymentSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _CheckoutCard(
        title: 'Payment Details',
        child: Column(
          children: [
            _CheckoutAmountRow(
              label: 'Merchandise Subtotal',
              value: _peso(_productTotal),
            ),
            const SizedBox(height: 12),
            _CheckoutAmountRow(
              label: 'Shipping Subtotal',
              value: _shippingTotal == 0 ? '₱0.00' : _peso(_shippingTotal),
            ),
            if (_electronicProtectionTotal > 0) ...[
              const SizedBox(height: 12),
              _CheckoutAmountRow(
                label: 'Electronic Protection',
                value: _peso(_electronicProtectionTotal),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: _border),
            ),
            _CheckoutAmountRow(
              label: 'Total Payment',
              value: _peso(_estimatedTotal),
              strong: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return SafeArea(
      bottom: false,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildHeroHeader(mobile: false),
                        const SizedBox(height: 18),
                        _buildRecipientCard(),
                        const SizedBox(height: 16),
                        _buildAddressCard(),
                        const SizedBox(height: 16),
                        if (widget.requireCourierSelection)
                          ..._buildSellerSections(),
                        _buildPaymentCard(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 330,
                    child: _buildSummaryCard(showButton: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader({required bool mobile}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E7DD),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'SECURE CHECKOUT',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Review and place your order',
                style: TextStyle(
                  color: _text,
                  fontSize: mobile ? 25 : 34,
                  height: 1.06,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Confirm recipient details, delivery address, and payment method.',
                style: TextStyle(color: _muted, fontSize: 14, height: 1.45),
              ),
            ],
          ),
        ),
        if (!mobile) ...[
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: _handleBack,
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(color: Color(0xFFC49A7A)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Back to Cart',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecipientCard() {
    return _CheckoutCard(
      title: 'Recipient',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool sideBySide = constraints.maxWidth >= 640;

          if (sideBySide) {
            return Row(
              children: [
                Expanded(child: _buildRecipientNameField()),
                const SizedBox(width: 14),
                Expanded(child: _buildContactField()),
              ],
            );
          }

          return Column(
            children: [
              _buildRecipientNameField(),
              const SizedBox(height: 12),
              _buildContactField(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecipientNameField() {
    return TextFormField(
      controller: _recipientController,
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(
        label: 'Full name',
        hint: 'Recipient full name',
      ),
      validator: (String? value) {
        final String text = value?.trim() ?? '';
        if (text.isEmpty) {
          return 'Full name is required.';
        }
        if (text.length > 160) {
          return 'Full name is too long.';
        }
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildContactField() {
    return TextFormField(
      controller: _contactController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      decoration: _inputDecoration(
        label: 'Contact number',
        hint: 'Contact number',
      ),
      validator: (String? value) {
        final String text = value?.trim() ?? '';
        if (text.isEmpty) {
          return 'Contact number is required.';
        }
        if (text.length > 40) {
          return 'Contact number is too long.';
        }
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildAddressCard() {
    final CheckoutAddressData? selectedAddress = _selectedAddress;

    return _CheckoutCard(
      title: 'Delivery address',
      subtitle:
          'Confirm the complete address where the order should be delivered.',
      leadingIcon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.addresses.isEmpty)
            _InfoBanner(
              icon: Icons.location_off_outlined,
              text:
                  'No delivery address is available. Add an address before placing an order.',
              danger: true,
            )
          else ...[
            DropdownButtonFormField<int>(
              initialValue: _selectedAddressId,
              isExpanded: true,
              menuMaxHeight: 340,
              decoration: _inputDecoration(
                label: 'Address',
                hint: 'Choose address',
              ),
              items: widget.addresses.map((CheckoutAddressData address) {
                return DropdownMenuItem<int>(
                  value: address.id,
                  child: Text(
                    '${address.label} - ${address.shortAddress}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (int? value) {
                setState(() {
                  _selectedAddressId = value;
                });
              },
              validator: (int? value) {
                if (value == null) {
                  return 'Please choose a delivery address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            if (selectedAddress != null)
              Text(
                selectedAddress.fullAddress,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSellerSections() {
    final List<Widget> widgets = <Widget>[];

    for (final MapEntry<int, List<CheckoutItemData>> entry
        in _groupedItems.entries) {
      final int sellerId = entry.key;
      final List<CheckoutItemData> shopItems = entry.value;
      final String sellerName = shopItems.first.seller;

      final List<CheckoutCourierOption> options =
          widget.couriersBySeller[sellerId] ?? const <CheckoutCourierOption>[];

      widgets.add(
        _CheckoutCard(
          title: sellerName,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _selectedCouriers[sellerId],
                isExpanded: true,
                menuMaxHeight: 340,
                decoration: _inputDecoration(
                  label: 'Courier',
                  hint: 'Choose courier',
                ),
                items: options.map((CheckoutCourierOption option) {
                  return DropdownMenuItem<int>(
                    value: option.id,
                    child: Text(
                      '${option.name} - ${_peso(option.fee)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: options.isEmpty
                    ? null
                    : (int? value) {
                        setState(() {
                          _selectedCouriers[sellerId] = value;
                        });
                      },
                validator: (int? value) {
                  if (options.isEmpty) {
                    return null;
                  }
                  if (value == null) {
                    return 'Please choose a courier.';
                  }
                  return null;
                },
              ),
              if (options.isEmpty) ...[
                const SizedBox(height: 10),
                const _InfoBanner(
                  icon: Icons.warning_amber_rounded,
                  text: 'No approved courier currently serves this address.',
                  danger: true,
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _shopNoteControllers[sellerId],
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 3,
                maxLines: 4,
                maxLength: 500,
                decoration: _inputDecoration(
                  label: 'Message to shop',
                  hint: 'Optional note for the seller',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      );

      widgets.add(const SizedBox(height: 14));
    }

    return widgets;
  }

  Widget _buildPaymentCard() {
    return _CheckoutCard(
      title: 'Payment method',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool sideBySide = constraints.maxWidth >= 640;

          if (sideBySide) {
            return Row(
              children: [
                Expanded(
                  child: _PaymentOptionTile(
                    selected: true,
                    title: 'Cash on Delivery',
                    subtitle: 'Pay when your parcel arrives.',
                    enabled: true,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: _PaymentOptionTile(
                    selected: false,
                    title: 'Online Payment (unavailable)',
                    subtitle: 'Currently unavailable.',
                    enabled: false,
                  ),
                ),
              ],
            );
          }

          return const Column(
            children: [
              _PaymentOptionTile(
                selected: true,
                title: 'Cash on Delivery',
                subtitle: 'Pay when your parcel arrives.',
                enabled: true,
              ),
              SizedBox(height: 10),
              _PaymentOptionTile(
                selected: false,
                title: 'Online Payment (unavailable)',
                subtitle: 'Currently unavailable.',
                enabled: false,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({required bool showButton}) {
    return _CheckoutCard(
      title: 'Order summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int index = 0; index < widget.items.length; index++) ...[
            _SummaryItem(item: widget.items[index], pesoFormatter: _peso),
            if (widget.items[index].isProtectionEligible)
              _ElectronicProtectionTile(
                selected: _protectedProductIds.contains(
                  widget.items[index].productId,
                ),
                fee: _protectionFeeFor(widget.items[index]),
                onChanged: (bool selected) {
                  setState(() {
                    if (selected) {
                      _protectedProductIds.add(widget.items[index].productId);
                    } else {
                      _protectedProductIds.remove(
                        widget.items[index].productId,
                      );
                    }
                  });
                },
              ),
            if (index < widget.items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: _border),
              ),
          ],
          const SizedBox(height: 16),
          if (widget.appliedVoucherCodes.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1E4D7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Voucher applied: ${widget.appliedVoucherCodes.values.join(', ')}',
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Divider(height: 1, color: _border),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total payment',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ),
              Text(
                _peso(_estimatedTotal),
                style: const TextStyle(
                  color: _text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Courier fees are recalculated securely when you place the order.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
          ),
          if (showButton) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _canPlaceOrder ? _handlePlaceOrder : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  disabledBackgroundColor: _disabled,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Place Order',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: _surface,
          border: const Border(top: BorderSide(color: _border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 22,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _peso(_estimatedTotal),
                    style: const TextStyle(
                      color: _primaryDark,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _canPlaceOrder ? _handlePlaceOrder : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  disabledBackgroundColor: _disabled,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Place Order',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: _surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: _primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your cart is empty',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add a product before checking out.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _handleBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to Cart'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: _surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      labelStyle: const TextStyle(
        color: _muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: Color(0xFFB59F92), fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCDA98E), width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _danger, width: 1.3),
      ),
    );
  }
}

class _MobileCheckoutItem extends StatelessWidget {
  const _MobileCheckoutItem({required this.item, required this.peso});

  final CheckoutItemData item;
  final String Function(double) peso;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 78,
            height: 78,
            color: const Color(0xFFF4F4F4),
            child: _ProductImage(imageUrl: item.imageUrl),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF292929),
                  fontSize: 13.5,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                item.variant.isEmpty ? 'Standard' : item.variant,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF858585), fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    peso(item.lineTotal),
                    style: const TextStyle(
                      color: Color(0xFFE05A3F),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'x${item.safeQuantity}',
                    style: const TextStyle(
                      color: Color(0xFF858585),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ElectronicProtectionTile extends StatelessWidget {
  const _ElectronicProtectionTile({
    required this.selected,
    required this.fee,
    required this.onChanged,
  });

  final bool selected;
  final double fee;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: selected ? const Color(0xFFFFF3EE) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: () => onChanged(!selected),
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (bool? value) => onChanged(value ?? false),
                  activeColor: const Color(0xFFE05A3F),
                  visualDensity: VisualDensity.compact,
                ),
                const Icon(
                  Icons.verified_user_outlined,
                  size: 19,
                  color: Color(0xFFE05A3F),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Electronic Protection',
                        style: TextStyle(
                          color: Color(0xFF292929),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Protect against accidental damage during delivery.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF858585),
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '+₱${fee.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFE05A3F),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckoutActionRow extends StatelessWidget {
  const _CheckoutActionRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3EE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFFE05A3F)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF292929),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(color: Color(0xFF858585), fontSize: 12),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, color: Color(0xFFAAAAAA), size: 20),
      ],
    );
  }
}

class _CheckoutAmountRow extends StatelessWidget {
  const _CheckoutAmountRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? const Color(0xFF292929) : const Color(0xFF666666),
              fontSize: strong ? 16 : 13,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: strong ? const Color(0xFF292929) : const Color(0xFF666666),
            fontSize: strong ? 17 : 13,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CheckoutCard extends StatelessWidget {
  const _CheckoutCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.leadingIcon,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget child;

  static const Color _surface = Colors.white;
  static const Color _border = Color(0xFFE8E8E8);
  static const Color _text = Color(0xFF292929);
  static const Color _muted = Color(0xFF7E7E7E);
  static const Color _surfaceSoft = Color(0xFFFFF3EE);
  static const Color _primary = Color(0xFFE05A3F);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leadingIcon != null || subtitle != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leadingIcon != null) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(leadingIcon, size: 19, color: _primary),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
          else
            Text(
              title,
              style: const TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
    this.danger = false,
  });

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color fg = danger ? const Color(0xFFB42318) : const Color(0xFF6F2017);
    final Color bg = danger ? const Color(0xFFFFEFEA) : const Color(0xFFF4EAE0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: fg),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.enabled,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final bool enabled;

  static const Color _primary = Color(0xFF6F2017);
  static const Color _primaryBg = Color(0xFFFFF0EE);
  static const Color _disabledBg = Color(0xFFF5F0EA);
  static const Color _disabledText = Color(0xFFA09187);
  static const Color _border = Color(0xFFE4D6C8);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? _primaryBg : _disabledBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? _primary.withValues(alpha: 0.65) : _border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? _primary : _disabledText,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: enabled
                        ? (selected ? _primary : const Color(0xFF614B41))
                        : _disabledText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: enabled ? const Color(0xFF8D776C) : _disabledText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.item, required this.pesoFormatter});

  final CheckoutItemData item;
  final String Function(double) pesoFormatter;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 56,
            height: 56,
            color: const Color(0xFFF3ECE6),
            child: _ProductImage(imageUrl: item.imageUrl),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF3B231C),
                  fontSize: 13.5,
                  height: 1.28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.variant.isEmpty ? 'Standard' : item.variant} · Qty ${item.safeQuantity}',
                style: const TextStyle(
                  color: Color(0xFF8D776C),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          pesoFormatter(item.lineTotal),
          style: const TextStyle(
            color: Color(0xFF3B231C),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final String url = (imageUrl ?? '').trim();

    if (url.isEmpty) {
      return const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFFAA998E)),
      );
    }

    return Image(
      image: CachedNetworkImageProvider(url),
      fit: BoxFit.cover,
      loadingBuilder:
          (
            BuildContext context,
            Widget child,
            ImageChunkEvent? loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }

            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Color(0xFFAA998E),
              ),
            );
          },
    );
  }
}

class CheckoutItemData {
  const CheckoutItemData({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.seller,
    required this.name,
    required this.price,
    required this.quantity,
    this.category = '',
    this.productVariantId,
    this.variant = '',
    this.imageUrl,
  });

  final int id;
  final int productId;
  final int? productVariantId;
  final int sellerId;
  final String seller;
  final String name;
  final String category;
  final String variant;
  final double price;
  final int quantity;
  final String? imageUrl;

  int get safeQuantity => quantity < 1 ? 1 : quantity;

  double get lineTotal => price * safeQuantity;

  bool get isProtectionEligible {
    final String searchable = '$category $name'.toLowerCase();
    const List<String> keywords = <String>[
      'electronic',
      'electronics',
      'mobile',
      'smartphone',
      'phone',
      'tablet',
      'laptop',
      'computer',
      'monitor',
      'camera',
      'television',
      'tv ',
      'gadget',
      'headphone',
      'earphone',
      'speaker',
      'console',
      'appliance',
    ];
    return keywords.any(searchable.contains);
  }

  factory CheckoutItemData.fromJson(Map<String, dynamic> json) {
    return CheckoutItemData(
      id: _asInt(json['id']),
      productId: _asInt(json['product_id']),
      productVariantId: _asNullableInt(json['product_variant_id']),
      sellerId: _asInt(json['seller_id']),
      seller: (json['seller'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      variant: (json['variant'] ?? '').toString(),
      price: _asDouble(json['price']),
      quantity: _asInt(json['quantity'], fallback: 1),
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString(),
    );
  }
}

class CheckoutAddressData {
  const CheckoutAddressData({
    required this.id,
    required this.label,
    required this.recipient,
    required this.phone,
    required this.province,
    required this.city,
    required this.barangay,
    required this.postalCode,
    this.line1,
    this.region,
    this.landmark,
    this.isDefault = false,
  });

  final int id;
  final String label;
  final String recipient;
  final String phone;
  final String? line1;
  final String? region;
  final String province;
  final String city;
  final String barangay;
  final String postalCode;
  final String? landmark;
  final bool isDefault;

  String get shortAddress {
    return <String?>[line1, barangay, city, province]
        .where((String? value) => value != null && value.trim().isNotEmpty)
        .join(', ');
  }

  String get fullAddress {
    return <String?>[line1, barangay, city, province, postalCode]
        .where((String? value) => value != null && value.trim().isNotEmpty)
        .join(', ');
  }

  factory CheckoutAddressData.fromJson(Map<String, dynamic> json) {
    return CheckoutAddressData(
      id: _asInt(json['id']),
      label: (json['label'] ?? '').toString(),
      recipient: (json['recipient'] ?? json['recipient_name'] ?? '').toString(),
      phone: (json['phone'] ?? json['contact_number'] ?? '').toString(),
      line1: json['line1']?.toString(),
      region: json['region']?.toString(),
      province: (json['province'] ?? '').toString(),
      city: (json['city'] ?? json['municipality'] ?? '').toString(),
      barangay: (json['barangay'] ?? '').toString(),
      postalCode: (json['postal_code'] ?? '').toString(),
      landmark: json['landmark']?.toString(),
      isDefault: _asBool(json['is_default']),
    );
  }
}

class CheckoutCourierOption {
  const CheckoutCourierOption({
    required this.id,
    required this.name,
    required this.feeMinor,
  });

  final int id;
  final String name;
  final int feeMinor;

  double get fee => feeMinor / 100;

  factory CheckoutCourierOption.fromJson(Map<String, dynamic> json) {
    return CheckoutCourierOption(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      feeMinor: _asInt(json['fee_minor']),
    );
  }
}

class CheckoutPlaceOrderRequest {
  const CheckoutPlaceOrderRequest({
    required this.checkoutToken,
    required this.recipientName,
    required this.contactNumber,
    required this.addressId,
    required this.couriersBySeller,
    required this.notesBySeller,
    this.protectedProductIds = const <int>[],
    this.paymentMethod = 'cod',
  });

  final String checkoutToken;
  final String recipientName;
  final String contactNumber;
  final int addressId;
  final Map<int, int> couriersBySeller;
  final Map<int, String> notesBySeller;
  final List<int> protectedProductIds;
  final String paymentMethod;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'checkout_token': checkoutToken,
      'recipient_name': recipientName,
      'contact_number': contactNumber,
      'address_id': addressId,
      'courier': couriersBySeller.map(
        (int sellerId, int courierId) =>
            MapEntry(sellerId.toString(), courierId),
      ),
      'notes': notesBySeller.map(
        (int sellerId, String note) => MapEntry(sellerId.toString(), note),
      ),
      if (protectedProductIds.isNotEmpty)
        'protected_product_ids': protectedProductIds,
      'payment_method': paymentMethod,
    };
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final String normalized = (value?.toString() ?? '').toLowerCase().trim();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}
