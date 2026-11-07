import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/sized_network_image.dart';
import '../../../services/workspace_mobile_service.dart';

class SellerOffersScreen extends StatefulWidget {
  final String? offerType;

  const SellerOffersScreen({super.key, this.offerType});
  @override
  State<SellerOffersScreen> createState() => _SellerOffersScreenState();
}

class _SellerOffersScreenState extends State<SellerOffersScreen> {
  late Future<List<Map<String, dynamic>>> _future = WorkspaceMobileService.rows(
    'buyer/offers',
  );
  bool _busy = false;
  String? _message, _error;
  final Map<String, String> _offerSets = <String, String>{};
  void _reload() =>
      setState(() => _future = WorkspaceMobileService.rows('buyer/offers'));

  Future<void> _claim(Map<String, dynamic> offer) async {
    final rewards = WorkspaceMobileService.maps(offer['rewards']);
    String? rewardVariantId;
    if (offer['type'] != 'BUNDLE') {
      if (rewards.isEmpty) {
        setState(
          () => _error = 'This offer has no available reward variation.',
        );
        return;
      }
      if (rewards.length == 1) {
        rewardVariantId = '${rewards.first['id']}';
      } else {
        rewardVariantId = await showDialog<String>(
          context: context,
          builder: (context) {
            String selected = '${rewards.first['id']}';
            return StatefulBuilder(
              builder: (context, setDialog) => AlertDialog(
                title: const Text('Choose your reward variation'),
                content: DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  items: rewards
                      .map(
                        (reward) => DropdownMenuItem<String>(
                          value: '${reward['id']}',
                          child: Text('${reward['name'] ?? 'Variation'}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialog(() => selected = value ?? selected),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, selected),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            );
          },
        );
        if (!mounted || rewardVariantId == null) return;
      }
    }
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final component in WorkspaceMobileService.maps(offer['components'])) {
      final group = '${component['choice_group'] ?? ''}';
      if (group.isNotEmpty) {
        groups
            .putIfAbsent(group, () => [])
            .add(Map<String, dynamic>.from(component));
      }
    }
    final choices = <String, String>{};
    if (groups.isNotEmpty) {
      final picked = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) {
          final values = <String, String>{
            for (final entry in groups.entries)
              entry.key: '${entry.value.first['variant']?['id'] ?? ''}',
          };
          return StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
              title: const Text('Choose bundle options'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in groups.entries)
                    DropdownButtonFormField<String>(
                      initialValue: values[entry.key],
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Option ${entry.key}',
                      ),
                      items: entry.value
                          .map(
                            (item) => DropdownMenuItem(
                              value: '${item['variant']?['id']}',
                              child: Text(
                                '${item['variant']?['name'] ?? 'Variant'}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialog(
                        () => values[entry.key] = value ?? values[entry.key]!,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, values),
                  child: const Text('Add to cart'),
                ),
              ],
            ),
          );
        },
      );
      if (picked == null) return;
      choices.addAll(picked);
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final String offerId = '${offer['id']}';
      final int maxSets = _maxSets(offer);
      final int requestedSets = int.tryParse(_offerSets[offerId] ?? '1') ?? 1;
      final int sets = maxSets == 0
          ? 1
          : requestedSets.clamp(1, maxSets).toInt();
      final form = FormData()..fields.add(MapEntry('sets', '$sets'));
      for (final choice in choices.entries) {
        form.fields.add(MapEntry('choices[${choice.key}]', choice.value));
      }
      final path = offer['type'] == 'BUNDLE'
          ? 'buyer/cart/bundles/${offer['id']}'
          : 'buyer/cart/offers/${offer['id']}/claim';
      if (rewardVariantId != null) {
        form.fields.add(MapEntry('reward_variant_id', rewardVariantId));
      }
      final result = await WorkspaceMobileService.send(path, form);
      if (mounted) {
        setState(
          () => _message =
              result['message']?.toString() ?? 'Offer items added to cart.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatAmount(double amount) {
    final List<String> parts = amount.toStringAsFixed(2).split('.');
    final String grouped = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (Match match) => ',',
    );
    return '$grouped.${parts.last}';
  }

  String _peso(double amount) =>
      String.fromCharCode(0x20B1) + ' ' + _formatAmount(amount);

  Widget _offerPill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF7E9E2),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF6A2019),
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    ),
  );

  int? _redemptionsRemaining(Map<String, dynamic> offer) {
    final dynamic remainingValue = offer['redemptions_remaining'];
    final dynamic maximumValue = offer['max_redemptions'];
    final dynamic usedValue = offer['redemptions_used'];
    if (maximumValue == null && remainingValue == null) return null;
    final int remaining =
        int.tryParse(remainingValue?.toString() ?? '') ??
        (int.tryParse(maximumValue?.toString() ?? '') ?? 0) -
            (int.tryParse(usedValue?.toString() ?? '') ?? 0);
    return remaining.clamp(0, 999999).toInt();
  }

  int _maxSets(Map<String, dynamic> offer) {
    int maximum = _redemptionsRemaining(offer) ?? 99;
    final int? buyerLimit = int.tryParse(
      offer['max_per_buyer']?.toString() ?? '',
    );
    if (buyerLimit != null && buyerLimit > 0) {
      maximum = maximum < buyerLimit ? maximum : buyerLimit;
    }
    return maximum.clamp(0, 99).toInt();
  }

  String _dateLabel(String? value) {
    final DateTime? date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return '';
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
    final int hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final String minute = date.minute.toString().padLeft(2, '0');
    final String period = date.hour < 12 ? 'AM' : 'PM';
    return months[date.month - 1] +
        ' ' +
        date.day.toString() +
        ', ' +
        date.year.toString() +
        ' ' +
        hour.toString() +
        ':' +
        minute +
        ' ' +
        period;
  }

  Widget _productThumbnail(String? path, {double size = 48}) {
    final String imageUrl = path == null || path.trim().isEmpty
        ? ''
        : AppConfig.resolveMediaUrl(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl.isEmpty
            ? Container(
                color: const Color(0xFFF3E9E2),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_outlined,
                  color: Color(0xFF8B6757),
                  size: 20,
                ),
              )
            : SizedNetworkImage(
                url: imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: const Color(0xFFF3E9E2),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_outlined,
                    color: Color(0xFF8B6757),
                    size: 20,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _setsField({
    required String offerId,
    required String label,
    required int maximum,
  }) {
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF67483B),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 36,
            child: TextFormField(
              key: ValueKey<String>('sets-' + offerId),
              initialValue: _offerSets[offerId] ?? '1',
              enabled: maximum > 0,
              keyboardType: TextInputType.number,
              onChanged: (value) => _offerSets[offerId] = value,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: Color(0xFFE6D6C8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: Color(0xFFE6D6C8)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _offerCard(Map<String, dynamic> offer) {
    const Color maroon = Color(0xFF651F18);
    const Color muted = Color(0xFF776B65);
    const Color border = Color(0xFFE9DCCF);
    final bool isBundle = offer['type'] == 'BUNDLE';
    final List<Map<String, dynamic>> components = WorkspaceMobileService.maps(
      offer['components'],
    );
    final List<Map<String, dynamic>> rewards = WorkspaceMobileService.maps(
      offer['rewards'],
    );
    final Map<String, dynamic>? buyItem = offer['buy_item'] is Map
        ? Map<String, dynamic>.from(offer['buy_item'] as Map)
        : null;
    final int maximum = _maxSets(offer);
    final String offerId = offer['id']?.toString() ?? '';
    final String name = offer['name']?.toString().trim().isNotEmpty == true
        ? offer['name'].toString().trim()
        : (isBundle ? 'Bundle deal' : 'Buy X Get Y');
    final int buyQuantity =
        int.tryParse((offer['buy_quantity'] ?? 1).toString()) ?? 1;
    final int rewardQuantity =
        int.tryParse((offer['reward_quantity'] ?? 1).toString()) ?? 1;
    final double discount =
        double.tryParse((offer['reward_discount_percent'] ?? 100).toString()) ??
        100;
    final double? bundlePrice = double.tryParse(
      offer['bundle_price']?.toString() ?? '',
    );
    final double? usualTotal = double.tryParse(
      offer['usual_total']?.toString() ?? '',
    );
    final double? savings = double.tryParse(offer['savings']?.toString() ?? '');
    final bool canAdd = (isBundle || rewards.isNotEmpty) && maximum > 0;
    final String dateStart = _dateLabel(offer['starts_at']?.toString());
    final String dateEnd = _dateLabel(offer['ends_at']?.toString());
    final List<Map<String, dynamic>> previewItems = isBundle
        ? components
        : <Map<String, dynamic>>[
            if (buyItem != null) buyItem,
            if (rewards.isNotEmpty) rewards.first,
          ];

    String productName(Map<String, dynamic>? item, {String fallback = 'item'}) {
      if (item == null) return fallback;
      return item['product_name']?.toString() ??
          item['name']?.toString() ??
          fallback;
    }

    String imagePath(dynamic value) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is Map) {
        for (final key in const <String>['url', 'file_path', 'path']) {
          final dynamic path = value[key];
          if (path is String && path.trim().isNotEmpty) return path.trim();
        }
      }
      return '';
    }

    String productImage(Map<String, dynamic> item) {
      for (final key in const <String>[
        'image',
        'image_url',
        'thumbnail',
        'primary_image',
      ]) {
        final String path = imagePath(item[key]);
        if (path.isNotEmpty) return path;
      }

      final dynamic images = item['images'];
      if (images is List && images.isNotEmpty) {
        final dynamic primary = images.cast<dynamic>().firstWhere(
          (dynamic image) => image is Map && image['is_primary'] == true,
          orElse: () => images.first,
        );
        final String path = imagePath(primary);
        if (path.isNotEmpty) return path;
      }

      for (final key in const <String>[
        'variant',
        'product_variant',
        'product',
      ]) {
        final dynamic nested = item[key];
        if (nested is Map) {
          final String path = productImage(Map<String, dynamic>.from(nested));
          if (path.isNotEmpty) return path;
        }
      }
      return '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isBundle && previewItems.isNotEmpty) ...[
            Row(
              children: [
                for (final item in previewItems.take(3)) ...[
                  _productThumbnail(productImage(item), size: 48),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(
            isBundle ? 'BUNDLE DEAL' : 'BUY X GET Y',
            style: const TextStyle(
              color: Color(0xFF7B2C23),
              fontSize: 9,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFF241E1A),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          if (isBundle)
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: muted,
                  fontSize: 12,
                  height: 1.35,
                ),
                children: [
                  const TextSpan(text: 'Get all listed items together for '),
                  TextSpan(
                    text: bundlePrice == null
                        ? 'a special price.'
                        : _peso(bundlePrice) + '.',
                    style: const TextStyle(
                      color: maroon,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Buy ' +
                  buyQuantity.toString() +
                  ' x ' +
                  productName(buyItem, fallback: 'qualifying item') +
                  ', get ' +
                  rewardQuantity.toString() +
                  ' x ' +
                  productName(
                    rewards.isEmpty ? null : rewards.first,
                    fallback: 'reward item',
                  ) +
                  (discount >= 100
                      ? ' free.'
                      : ' at ' + discount.toStringAsFixed(0) + '% off.'),
              style: const TextStyle(color: muted, fontSize: 12, height: 1.35),
            ),
          if (isBundle && usualTotal != null && savings != null) ...[
            const SizedBox(height: 3),
            Text.rich(
              TextSpan(
                style: const TextStyle(color: muted, fontSize: 10),
                children: [
                  const TextSpan(text: 'Usual total '),
                  TextSpan(
                    text: _peso(usualTotal),
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  TextSpan(
                    text: '   Save ' + _peso(savings),
                    style: const TextStyle(
                      color: maroon,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isBundle && components.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (final item in components.take(3)) ...[
                  _productThumbnail(productImage(item), size: 48),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ],
          if (!isBundle &&
              int.tryParse(offer['max_per_buyer']?.toString() ?? '') !=
                  null) ...[
            const SizedBox(height: 3),
            Text(
              'Limit ' +
                  offer['max_per_buyer'].toString() +
                  ' redemption(s) per buyer.',
              style: const TextStyle(color: muted, fontSize: 10),
            ),
          ],
          if (isBundle && components.isNotEmpty) ...[
            const SizedBox(height: 9),
            for (final item in components)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  (item['quantity'] ?? 1).toString() +
                      ' x ' +
                      productName(
                        item['variant'] is Map
                            ? Map<String, dynamic>.from(item['variant'] as Map)
                            : item,
                        fallback: 'Bundle item',
                      ) +
                      ((item['variant'] is Map &&
                              (item['variant'] as Map)['variant_name'] != null)
                          ? ' - ' +
                                (item['variant'] as Map)['variant_name']
                                    .toString()
                          : ''),
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
              ),
          ],
          if (offer['max_redemptions'] != null) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: _offerPill(
                (_redemptionsRemaining(offer) ?? 0).toString() +
                    (isBundle ? ' bundle set(s) left' : ' redemption(s) left'),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _setsField(
                offerId: offerId,
                label: isBundle ? 'Bundle sets' : 'Offer sets',
                maximum: maximum,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: FilledButton(
                    onPressed: _busy || !canAdd ? null : () => _claim(offer),
                    style: FilledButton.styleFrom(
                      backgroundColor: maroon,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD6C1BC),
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: Text(
                      _busy
                          ? 'Adding...'
                          : canAdd
                          ? (isBundle
                                ? 'Add Bundle to Cart'
                                : 'Add Items & Claim')
                          : (maximum == 0
                                ? 'Offer fully redeemed'
                                : 'Reward unavailable'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (dateStart.isNotEmpty || dateEnd.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              (dateStart.isEmpty ? 'Available now' : dateStart) +
                  (dateEnd.isEmpty ? '' : ' - ' + dateEnd),
              style: const TextStyle(color: muted, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAF6F2),
    appBar: AppBar(
      title: Text(switch (widget.offerType) {
        'BUNDLE' => 'Bundle deals',
        'BUY_X_GET_Y' => 'Free gifts',
        _ => 'Seller offers',
      }),
      actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final offers = (snapshot.data ?? const <Map<String, dynamic>>[])
            .where(
              (offer) =>
                  widget.offerType == null || offer['type'] == widget.offerType,
            )
            .toList(growable: false);
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              const Text(
                'SELLER PROMOTIONS',
                style: TextStyle(
                  color: Color(0xFF6A2019),
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.offerType == 'BUNDLE'
                    ? 'Bundle Deals'
                    : widget.offerType == 'BUY_X_GET_Y'
                    ? 'Free Gifts & Rewards'
                    : 'Seller Promotions',
                style: const TextStyle(
                  color: Color(0xFF651F18),
                  fontFamily: 'serif',
                  fontSize: 29,
                  height: 1.04,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                widget.offerType == 'BUNDLE'
                    ? 'Shop selected items together at one bundle price. Available combinations and stock are confirmed in your cart.'
                    : widget.offerType == 'BUY_X_GET_Y'
                    ? 'See what qualifies, choose eligible reward variations, and add the offer through the existing cart flow.'
                    : 'Explore seller bundle deals and Buy X Get Y rewards.',
                style: const TextStyle(
                  color: Color(0xFF8A6656),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.push('/buyer/products'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF34241F),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Browse products',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 13),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.offerType == 'BUNDLE'
                    ? 'SAVE WHEN YOU SHOP TOGETHER'
                    : widget.offerType == 'BUY_X_GET_Y'
                    ? 'FREE GIFTS AND REWARD DISCOUNTS'
                    : 'SELLER DEALS AND REWARDS',
                style: const TextStyle(
                  color: Color(0xFF6A2019),
                  fontSize: 9,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.offerType == 'BUNDLE'
                    ? 'Available Bundle Deals'
                    : widget.offerType == 'BUY_X_GET_Y'
                    ? 'Available Buy X Get Y offers'
                    : 'Available seller offers',
                style: const TextStyle(
                  color: Color(0xFF29231F),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Offer prices are checked against available stock and confirmed at checkout.',
                style: TextStyle(
                  color: Color(0xFF625751),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot.hasError)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECE9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    style: const TextStyle(color: Color(0xFF8A2820)),
                  ),
                ),
              if (!snapshot.hasError && offers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9DCCF)),
                  ),
                  child: const Text(
                    'No offers are available right now. Check back later for new store promotions.',
                    style: TextStyle(color: Color(0xFF776B65), fontSize: 12),
                  ),
                ),
              if (_message != null)
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_message!),
                  ),
                ),
              if (_error != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!),
                  ),
                ),
              for (final offer in offers) _offerCard(offer),
            ],
          ),
        );
      },
    ),
  );
}
