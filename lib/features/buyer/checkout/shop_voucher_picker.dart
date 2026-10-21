import 'package:flutter/material.dart';

import '../../../core/theme/shop_colors.dart';
import '../rewards/rewards_screen.dart';

class ShopVoucherPicker extends StatefulWidget {
  const ShopVoucherPicker({
    super.key,
    required this.vouchers,
    required this.sellerNames,
    required this.sellerSubtotals,
    required this.initialCodes,
  });

  final List<RewardVoucherData> vouchers;
  final Map<int, String> sellerNames;
  final Map<int, double> sellerSubtotals;
  final Map<int, String> initialCodes;

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

  List<RewardVoucherData> get _shopVouchers => widget.vouchers
      .where(
        (RewardVoucherData voucher) =>
            voucher.sellerId != null &&
            widget.sellerNames.containsKey(voucher.sellerId) &&
            voucher.code.trim().isNotEmpty &&
            voucher.canUse != false,
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _selectedCodes = Map<int, String>.fromEntries(
      widget.initialCodes.entries.where(
        (MapEntry<int, String> entry) => widget.sellerNames.containsKey(
          entry.key,
        ),
      ),
    );
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
    if (sellerId == null) return;

    setState(() {
      if (_selectedCodes[sellerId]?.toUpperCase() ==
          voucher.code.toUpperCase()) {
        _selectedCodes.remove(sellerId);
      } else {
        _selectedCodes[sellerId] = voucher.code;
      }
    });
  }

  void _applyCode() {
    final String code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showMessage('Enter a shop voucher code.');
      return;
    }

    RewardVoucherData? match;
    for (final RewardVoucherData voucher in _shopVouchers) {
      if (voucher.code.trim().toUpperCase() == code) {
        match = voucher;
        break;
      }
    }

    final RewardVoucherData? selectedVoucher = match;
    if (selectedVoucher == null || selectedVoucher.sellerId == null) {
      _showMessage('That code is not an available voucher for these shops.');
      return;
    }

    final double minimum = selectedVoucher.minimumOrderAmount ?? 0;
    final double subtotal =
        widget.sellerSubtotals[selectedVoucher.sellerId!] ?? 0;
    if (subtotal < minimum) {
      final double remaining = minimum - subtotal;
      _showMessage(
        'Add ₱${remaining.toStringAsFixed(2)} more from this shop to use it.',
      );
      return;
    }

    setState(() {
      _selectedCodes[selectedVoucher.sellerId!] = selectedVoucher.code;
      _codeController.clear();
    });
    FocusScope.of(context).unfocus();
  }

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
                      'Select LIKHAE Vouchers',
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
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Shop vouchers',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${_shopVouchers.length} available',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            autocorrect: false,
                            cursorColor: _primary,
                            decoration: InputDecoration(
                              hintText: 'Enter shop voucher code',
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
                    if (_shopVouchers.isEmpty)
                      _buildEmptyVouchers()
                    else
                      for (final RewardVoucherData voucher in _shopVouchers)
                        _buildVoucherCard(voucher),
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
                    '${_selectedCodes.length} shop voucher${_selectedCodes.length == 1 ? '' : 's'} selected',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_selectedCodes),
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
        'No active vouchers are available for the shops in this checkout.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
      ),
    );
  }

  Widget _buildVoucherCard(RewardVoucherData voucher) {
    final int sellerId = voucher.sellerId!;
    final bool selected =
        _selectedCodes[sellerId]?.toUpperCase() == voucher.code.toUpperCase();
    final double minimum = voucher.minimumOrderAmount ?? 0;
    final double subtotal = widget.sellerSubtotals[sellerId] ?? 0;
    final bool meetsMinimum = subtotal >= minimum;
    final double remaining =
        (minimum - subtotal).clamp(0, double.infinity).toDouble();

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
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_offer_rounded, color: Colors.white),
                      SizedBox(height: 4),
                      Text(
                        'SHOP',
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
                        widget.sellerNames[sellerId] ??
                            voucher.sellerName ??
                            'Shop',
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
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 10,
                          ),
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
