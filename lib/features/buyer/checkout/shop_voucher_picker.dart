import 'package:flutter/material.dart';

import '../../../core/theme/shop_colors.dart';
import '../rewards/rewards_screen.dart';

class VoucherCodesSelection {
  const VoucherCodesSelection({
    this.sellerCodes = const <int, String>{},
    this.platformCode,
    this.shippingCode,
  });

  final Map<int, String> sellerCodes;
  final String? platformCode;
  final String? shippingCode;

  bool get isEmpty =>
      sellerCodes.isEmpty &&
      (platformCode?.trim().isEmpty ?? true) &&
      (shippingCode?.trim().isEmpty ?? true);

  Map<String, dynamic> toApiPayload() => <String, dynamic>{
    'seller': sellerCodes.map(
      (int sellerId, String code) =>
          MapEntry<String, String>(sellerId.toString(), code),
    ),
    'platform': platformCode?.trim() ?? '',
    'shipping': shippingCode?.trim() ?? '',
  };

  List<String> get codes => <String>[
    ...sellerCodes.values,
    if (platformCode?.trim().isNotEmpty == true) platformCode!.trim(),
    if (shippingCode?.trim().isNotEmpty == true) shippingCode!.trim(),
  ];
}

class ShopVoucherPicker extends StatefulWidget {
  const ShopVoucherPicker({
    super.key,
    required this.vouchers,
    required this.sellerNames,
    required this.sellerSubtotals,
    required this.initialCodes,
    this.initialPlatformCode,
    this.initialShippingCode,
  });

  final List<RewardVoucherData> vouchers;
  final Map<int, String> sellerNames;
  final Map<int, double> sellerSubtotals;
  final Map<int, String> initialCodes;
  final String? initialPlatformCode;
  final String? initialShippingCode;

  @override
  State<ShopVoucherPicker> createState() => _ShopVoucherPickerState();
}

class _ShopVoucherPickerState extends State<ShopVoucherPicker> {
  static const Color _primary = ShopColors.accent;
  static const Color _ink = ShopColors.text;
  static const Color _muted = ShopColors.muted;
  static const Color _border = ShopColors.border;
  static const Color _surface = ShopColors.surface;
  static const Color _canvas = ShopColors.canvas;

  late final TextEditingController _codeController;
  late final Map<int, String> _selectedCodes;
  String? _selectedPlatformCode;
  String? _selectedShippingCode;

  List<RewardVoucherData> get _shopVouchers => widget.vouchers
      .where(
        (RewardVoucherData voucher) =>
            voucher.voucherType == 'seller' &&
            voucher.sellerId != null &&
            widget.sellerNames.containsKey(voucher.sellerId) &&
            voucher.code.trim().isNotEmpty &&
            voucher.canUse != false,
      )
      .toList(growable: false);

  List<RewardVoucherData> get _platformVouchers => widget.vouchers
      .where(
        (RewardVoucherData voucher) =>
            voucher.voucherType == 'platform' &&
            voucher.sellerId == null &&
            voucher.code.trim().isNotEmpty &&
            voucher.canUse != false,
      )
      .toList(growable: false);

  List<RewardVoucherData> get _shippingVouchers => widget.vouchers
      .where(
        (RewardVoucherData voucher) =>
            voucher.voucherType == 'shipping' &&
            voucher.sellerId == null &&
            voucher.code.trim().isNotEmpty &&
            voucher.canUse != false,
      )
      .toList(growable: false);

  double get _cartSubtotal => widget.sellerSubtotals.values.fold<double>(
    0,
    (double total, double subtotal) => total + subtotal,
  );

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _selectedCodes = Map<int, String>.fromEntries(
      widget.initialCodes.entries.where(
        (MapEntry<int, String> entry) =>
            widget.sellerNames.containsKey(entry.key),
      ),
    );
    _selectedPlatformCode = widget.initialPlatformCode;
    _selectedShippingCode = widget.initialShippingCode;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectVoucher(RewardVoucherData voucher) {
    final int? sellerId = voucher.sellerId;
    setState(() {
      if (voucher.voucherType == 'platform') {
        _selectedPlatformCode =
            _selectedPlatformCode?.toUpperCase() == voucher.code.toUpperCase()
            ? null
            : voucher.code;
      } else if (voucher.voucherType == 'shipping') {
        _selectedShippingCode =
            _selectedShippingCode?.toUpperCase() == voucher.code.toUpperCase()
            ? null
            : voucher.code;
      } else if (sellerId != null) {
        if (_selectedCodes[sellerId]?.toUpperCase() ==
            voucher.code.toUpperCase()) {
          _selectedCodes.remove(sellerId);
        } else {
          _selectedCodes[sellerId] = voucher.code;
        }
      }
    });
  }

  void _applyCode() {
    final String code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showMessage('Enter a voucher code.');
      return;
    }

    RewardVoucherData? match;
    for (final RewardVoucherData voucher in <RewardVoucherData>[
      ..._shopVouchers,
      ..._platformVouchers,
      ..._shippingVouchers,
    ]) {
      if (voucher.code.trim().toUpperCase() == code) {
        match = voucher;
        break;
      }
    }

    final RewardVoucherData? selectedVoucher = match;
    if (selectedVoucher == null) {
      _showMessage('That code is not an available voucher for this cart.');
      return;
    }

    final double minimum = selectedVoucher.minimumOrderAmount ?? 0;
    final double subtotal = selectedVoucher.sellerId == null
        ? _cartSubtotal
        : widget.sellerSubtotals[selectedVoucher.sellerId] ?? 0;
    if (subtotal < minimum) {
      final double remaining = minimum - subtotal;
      _showMessage(
        'Add ₱${remaining.toStringAsFixed(2)} more from this shop to use it.',
      );
      return;
    }

    setState(() {
      if (selectedVoucher.voucherType == 'platform') {
        _selectedPlatformCode = selectedVoucher.code;
      } else if (selectedVoucher.voucherType == 'shipping') {
        _selectedShippingCode = selectedVoucher.code;
      } else if (selectedVoucher.sellerId != null) {
        _selectedCodes[selectedVoucher.sellerId!] = selectedVoucher.code;
      }
      _codeController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  VoucherCodesSelection get _selection => VoucherCodesSelection(
    sellerCodes: Map<int, String>.unmodifiable(_selectedCodes),
    platformCode: _selectedPlatformCode,
    shippingCode: _selectedShippingCode,
  );

  @override
  Widget build(BuildContext context) {
    final double availableHeight = MediaQuery.sizeOf(context).height * 0.84;

    return SafeArea(
      top: false,
      child: Container(
        height: availableHeight,
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Vouchers',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    color: _muted,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Expanded(
              child: ColoredBox(
                color: _canvas,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  children: [
                    _buildVoucherSection('Shop vouchers', _shopVouchers),
                    const SizedBox(height: 16),
                    _buildVoucherSection('LIKHAE vouchers', _platformVouchers),
                    const SizedBox(height: 16),
                    _buildVoucherSection(
                      'Shipping vouchers',
                      _shippingVouchers,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            autocorrect: false,
                            cursorColor: _primary,
                            decoration: InputDecoration(
                              hintText: 'Enter voucher code',
                              isDense: true,
                              filled: true,
                              fillColor: _surface,
                              hintStyle: const TextStyle(
                                color: ShopColors.faint,
                                fontSize: 12,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
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
                                borderSide: const BorderSide(
                                  color: _primary,
                                  width: 1.4,
                                ),
                              ),
                            ),
                            onSubmitted: (_) => _applyCode(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _applyCode,
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_shopVouchers.isEmpty &&
                        _platformVouchers.isEmpty &&
                        _shippingVouchers.isEmpty)
                      _buildEmptyVouchers(),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_selection.codes.length} voucher${_selection.codes.length == 1 ? '' : 's'} selected',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_selection),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
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

  Widget _buildEmptyVouchers() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ShopColors.soft,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'No active vouchers are available for this checkout.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
      ),
    );
  }

  Widget _buildVoucherSection(String title, List<RewardVoucherData> vouchers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${vouchers.length} available',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (vouchers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'No ${title.toLowerCase()} available for this cart.',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          )
        else
          for (final RewardVoucherData voucher in vouchers)
            _buildVoucherCard(voucher),
      ],
    );
  }

  Widget _buildVoucherCard(RewardVoucherData voucher) {
    final int? sellerId = voucher.sellerId;
    final bool selected = switch (voucher.voucherType) {
      'platform' =>
        _selectedPlatformCode?.toUpperCase() == voucher.code.toUpperCase(),
      'shipping' =>
        _selectedShippingCode?.toUpperCase() == voucher.code.toUpperCase(),
      _ =>
        sellerId != null &&
            _selectedCodes[sellerId]?.toUpperCase() ==
                voucher.code.toUpperCase(),
    };
    final double minimum = voucher.minimumOrderAmount ?? 0;
    final double subtotal = sellerId == null
        ? _cartSubtotal
        : widget.sellerSubtotals[sellerId] ?? 0;
    final bool meetsMinimum = subtotal >= minimum;
    final double remaining = (minimum - subtotal)
        .clamp(0, double.infinity)
        .toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? ShopColors.accentSoft : _surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: meetsMinimum || selected
              ? () => _selectVoucher(voucher)
              : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? _primary : _border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 70,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_offer_rounded, color: Colors.white),
                      SizedBox(height: 4),
                      Text(
                        switch (voucher.voucherType) {
                          'platform' => 'LIKHAE',
                          'shipping' => 'SHIP',
                          _ => 'SHOP',
                        },
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.value.isEmpty ? voucher.code : voucher.value,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (sellerId == null
                                ? null
                                : widget.sellerNames[sellerId]) ??
                            voucher.sellerName ??
                            (voucher.voucherType == 'platform'
                                ? 'LIKHAE Platform'
                                : voucher.voucherType == 'shipping'
                                ? 'Shipping benefit'
                                : 'Shop'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        !meetsMinimum
                            ? 'Add ₱${remaining.toStringAsFixed(2)} more · Code ${voucher.code}'
                            : '${voucher.condition} · Code ${voucher.code}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                      if (voucher.expires.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Valid until ${voucher.expires}',
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? _primary : ShopColors.borderStrong,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
