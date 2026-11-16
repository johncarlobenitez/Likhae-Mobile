import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../services/buyer_mobile_service.dart';
import '../../../services/product_service.dart';
import '../../../shared/widgets/sized_network_image.dart';
import '../../../services/workspace_mobile_service.dart';
import '../../../shared/widgets/shop_ui.dart';
import '../cart/cart_screen.dart';

class SellerOffersScreen extends StatefulWidget {
  final String? offerType;
  final Future<void> Function(List<CartItemData> items)? onBuyNowItems;

  const SellerOffersScreen({super.key, this.offerType, this.onBuyNowItems});
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

  Map<String, dynamic>? _offerMap(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : null;

  int? _firstOfferId(Iterable<dynamic> values) {
    for (final dynamic value in values) {
      final int? id = int.tryParse(value?.toString() ?? '');
      if (id != null && id > 0) return id;
    }
    return null;
  }

  int? _rewardVariantId(Map<String, dynamic> reward) {
    final Map<String, dynamic>? variant =
        _offerMap(reward['variant']) ?? _offerMap(reward['product_variant']);
    return _firstOfferId(<dynamic>[
      reward['product_variant_id'],
      reward['variant_id'],
      variant?['id'],
      reward['id'],
    ]);
  }

  List<Map<String, dynamic>> _offerRewards(Map<String, dynamic> offer) {
    for (final String key in const <String>[
      'rewards',
      'reward_items',
      'reward_variants',
      'gifts',
    ]) {
      final List<Map<String, dynamic>> rows =
          WorkspaceMobileService.maps(offer[key]);
      if (rows.isNotEmpty) return rows;
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _previewItemForRole(
    List<Map<String, dynamic>> items,
    Set<String> roles,
  ) {
    for (final Map<String, dynamic> item in items) {
      final String role = (item['role'] ?? '')
          .toString()
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z]'), '');
      if (roles.contains(role)) return item;
    }
    return null;
  }

  String? _offerProductName(Iterable<Map<String, dynamic>?> items) {
    for (final Map<String, dynamic>? item in items) {
      if (item == null) continue;
      final Map<String, dynamic>? product = _offerMap(item['product']);
      final Map<String, dynamic>? variant =
          _offerMap(item['variant']) ?? _offerMap(item['product_variant']);
      final Map<String, dynamic>? variantProduct =
          _offerMap(variant?['product']);
      for (final dynamic value in <dynamic>[
        item['product_name'],
        product?['name'],
        item['name'],
        variant?['product_name'],
        variantProduct?['name'],
      ]) {
        final String name = value?.toString().trim() ?? '';
        if (name.isNotEmpty) return name;
      }
    }
    return null;
  }

  String? _offerProductSlug(Iterable<Map<String, dynamic>?> items) {
    for (final Map<String, dynamic>? item in items) {
      if (item == null) continue;
      final Map<String, dynamic>? product = _offerMap(item['product']);
      final Map<String, dynamic>? variant =
          _offerMap(item['variant']) ?? _offerMap(item['product_variant']);
      final Map<String, dynamic>? variantProduct =
          _offerMap(variant?['product']);
      for (final dynamic value in <dynamic>[
        item['product_slug'],
        item['slug'],
        product?['slug'],
        variantProduct?['slug'],
      ]) {
        final String slug = value?.toString().trim() ?? '';
        if (slug.isNotEmpty) return slug;
      }
    }
    return null;
  }

  int? _offerProductId(
    Iterable<Map<String, dynamic>?> items, {
    int? variantId,
    Iterable<dynamic> productIds = const <dynamic>[],
  }) {
    final int? directId = _firstOfferId(productIds);
    if (directId != null) return directId;

    for (final Map<String, dynamic>? item in items) {
      if (item == null) continue;
      final Map<String, dynamic>? product = _offerMap(item['product']);
      final Map<String, dynamic>? variant =
          _offerMap(item['variant']) ?? _offerMap(item['product_variant']);
      final Map<String, dynamic>? variantProduct =
          _offerMap(variant?['product']);
      final int? productId = _firstOfferId(<dynamic>[
        item['product_id'],
        item['productId'],
        item['parent_product_id'],
        product?['id'],
        product?['product_id'],
        product?['productId'],
        product?['db_id'],
        variant?['product_id'],
        variant?['productId'],
        variantProduct?['id'],
        variantProduct?['product_id'],
        variantProduct?['productId'],
        variantProduct?['db_id'],
      ]);
      if (productId != null) return productId;

      // Some offer payloads expose a product row as the item itself, while
      // others expose a variant row. Avoid treating the selected variant ID
      // or a reward-row ID as a product ID when the payload is ambiguous.
      final int? itemId = _firstOfferId(<dynamic>[item['id']]);
      final bool hasVariantReference =
          item['product_variant_id'] != null ||
          item['variant_id'] != null ||
          variant != null;
      if (itemId != null && itemId != variantId && !hasVariantReference) {
        return itemId;
      }
    }
    return null;
  }

  Future<void> _claim(Map<String, dynamic> offer) async {
    final rewards = _offerRewards(offer);
    final List<Map<String, dynamic>> previewItems =
        WorkspaceMobileService.maps(offer['preview_items']);
    final Map<String, dynamic>? previewQualifyingItem =
        _previewItemForRole(previewItems, <String>{
          'QUALIFYING',
          'BUY',
          'BUYITEM',
          'BUYPRODUCT',
          'PRODUCTTOBUY',
          'ELIGIBLEPRODUCT',
        }) ??
        (previewItems.isNotEmpty &&
                (previewItems.first['role'] ?? '')
                        .toString()
                        .toUpperCase() !=
                    'REWARD'
            ? previewItems.first
            : null);
    final Map<String, dynamic>? previewRewardItem =
        _previewItemForRole(previewItems, <String>{
          'REWARD',
          'GIFT',
          'REWARDITEM',
          'REWARDPRODUCT',
          'GIFTITEM',
          'GIFTPRODUCT',
        }) ??
        (previewItems.length > 1 ? previewItems[1] : null);
    String? rewardVariantId;
    if (offer['type'] != 'BUNDLE') {
      if (rewards.isEmpty) {
        setState(
          () => _error = 'This offer has no available reward variation.',
        );
        return;
      }
      if (rewards.length == 1) {
        rewardVariantId = _rewardVariantId(rewards.first)?.toString();
      } else {
        rewardVariantId = await showDialog<String>(
          context: context,
          builder: (context) {
            String selected =
                _rewardVariantId(rewards.first)?.toString() ?? '';
            return StatefulBuilder(
              builder: (context, setDialog) => AlertDialog(
                title: const Text('Choose your reward variation'),
                content: DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  items: rewards
                      .map(
                          (reward) => DropdownMenuItem<String>(
                                value:
                                    _rewardVariantId(reward)?.toString() ?? '',
                                child: Text(
                                  '${reward['name'] ?? 'Variation'}',
                                ),
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
      if (offer['type'] == 'BUNDLE') {
        final form = FormData()..fields.add(MapEntry('sets', '$sets'));
        for (final choice in choices.entries) {
          form.fields.add(MapEntry('choices[${choice.key}]', choice.value));
        }
        final result = await WorkspaceMobileService.send(
          'buyer/cart/bundles/${offer['id']}',
          form,
        );
        if (mounted) {
          setState(
            () => _message =
                result['message']?.toString() ?? 'Bundle items added to cart.',
          );
        }
      } else {
        final int? selectedRewardVariantId = int.tryParse(
          rewardVariantId ?? '',
        );
        if (selectedRewardVariantId == null) {
          throw const FormatException(
            'Choose an available reward variation before continuing.',
          );
        }

        final Map<String, dynamic>? qualifyingItem =
            _offerMap(offer['buy_item']) ??
            _offerMap(offer['qualifying_item']) ??
            _offerMap(offer['buy_variant']) ??
            _offerMap(offer['product_to_buy']) ??
            _offerMap(offer['eligible_product']) ??
            previewQualifyingItem;
        final Map<String, dynamic>? qualifyingProduct =
            _offerMap(offer['buy_product']) ??
            _offerMap(offer['qualifying_product']) ??
            _offerMap(offer['product_to_buy']) ??
            _offerMap(offer['eligible_product']) ??
            _offerMap(offer['product']) ??
            _offerMap(previewQualifyingItem?['product']) ??
            _offerMap(qualifyingItem?['product']);
        final Map<String, dynamic>? qualifyingVariant =
            _offerMap(qualifyingItem?['variant']) ??
            _offerMap(qualifyingItem?['product_variant']) ??
            _offerMap(offer['buy_variant']) ??
            _offerMap(offer['qualifying_variant']) ??
            _offerMap(previewQualifyingItem?['variant']) ??
            _offerMap(previewQualifyingItem?['product_variant']);
        final int? qualifyingVariantId = _firstOfferId(<dynamic>[
          offer['buy_variant_id'],
          offer['buy_product_variant_id'],
          offer['qualifying_variant_id'],
          offer['qualifying_product_variant_id'],
          qualifyingItem?['product_variant_id'],
          qualifyingItem?['variant_id'],
          qualifyingVariant?['id'],
          qualifyingItem?['id'],
          previewQualifyingItem?['product_variant_id'],
          previewQualifyingItem?['variant_id'],
          _offerMap(previewQualifyingItem?['variant'])?['id'],
          _offerMap(previewQualifyingItem?['product_variant'])?['id'],
        ]);
        int? qualifyingProductId = _offerProductId(
          <Map<String, dynamic>?>[
            qualifyingProduct,
            qualifyingItem,
            qualifyingVariant,
            _offerMap(qualifyingVariant?['product']),
            previewQualifyingItem,
          ],
          variantId: qualifyingVariantId,
          productIds: <dynamic>[
            offer['buy_product_id'],
            offer['qualifying_product_id'],
            offer['product_id'],
          ],
        );
        if (qualifyingProductId == null && qualifyingVariantId != null) {
          qualifyingProductId = await ProductService.findProductIdForVariant(
            qualifyingVariantId,
            productName: _offerProductName(<Map<String, dynamic>?>[
              qualifyingProduct,
              qualifyingItem,
              previewQualifyingItem,
              qualifyingVariant,
            ]),
            slug: _offerProductSlug(<Map<String, dynamic>?>[
              qualifyingProduct,
              qualifyingItem,
              previewQualifyingItem,
              qualifyingVariant,
            ]),
          );
        }

        Map<String, dynamic>? selectedReward;
        for (final Map<String, dynamic> reward in rewards) {
          if (_rewardVariantId(reward) == selectedRewardVariantId) {
            selectedReward = reward;
            break;
          }
        }
        final Map<String, dynamic> rewardItem =
            selectedReward ?? rewards.first;
        final Map<String, dynamic>? offerRewardItem =
            _offerMap(offer['reward_item']);
        final Map<String, dynamic>? offerGiftItem =
            _offerMap(offer['gift_item']);
        final Map<String, dynamic>? rewardProduct =
            _offerMap(offer['reward_product']) ??
            _offerMap(offer['gift_product']) ??
            _offerMap(offerRewardItem?['product']) ??
            _offerMap(offerGiftItem?['product']) ??
            _offerMap(rewardItem['product']) ??
            _offerMap(previewRewardItem?['product']);
        final Map<String, dynamic>? rewardVariant =
            _offerMap(rewardItem['variant']) ??
            _offerMap(rewardItem['product_variant']) ??
            _offerMap(offerRewardItem?['variant']) ??
            _offerMap(offerGiftItem?['variant']) ??
            _offerMap(offer['reward_variant']) ??
            _offerMap(offer['gift_variant']) ??
            _offerMap(previewRewardItem?['variant']) ??
            _offerMap(previewRewardItem?['product_variant']);
        int? rewardProductId = _offerProductId(
          <Map<String, dynamic>?>[
            rewardProduct,
            rewardItem,
            rewardVariant,
            _offerMap(rewardVariant?['product']),
            previewRewardItem,
          ],
          variantId: selectedRewardVariantId,
          productIds: <dynamic>[
            offer['reward_product_id'],
            offer['gift_product_id'],
          ],
        );
        if (rewardProductId == null) {
          rewardProductId = await ProductService.findProductIdForVariant(
            selectedRewardVariantId,
            productName: _offerProductName(<Map<String, dynamic>?>[
              rewardProduct,
              rewardItem,
              previewRewardItem,
              rewardVariant,
            ]),
            slug: _offerProductSlug(<Map<String, dynamic>?>[
              rewardProduct,
              rewardItem,
              previewRewardItem,
              rewardVariant,
            ]),
          );
        }

        final List<CartItemData> items = await BuyerMobileService.buyNowOffer(
          promotionId: int.parse(offerId),
          sets: sets,
          rewardVariantId: selectedRewardVariantId,
          qualifyingProductId: qualifyingProductId,
          qualifyingVariantId: qualifyingVariantId,
          qualifyingQuantity: int.tryParse(
                (offer['buy_quantity'] ?? 1).toString(),
              ) ??
              1,
          rewardProductId: rewardProductId,
          rewardQuantity: int.tryParse(
                (offer['reward_quantity'] ?? 1).toString(),
              ) ??
              1,
        );
        if (!mounted) return;
        final Future<void> Function(List<CartItemData>)? onBuyNowItems =
            widget.onBuyNowItems;
        if (onBuyNowItems == null) {
          throw Exception('Free gift checkout is unavailable right now.');
        }
        await onBuyNowItems(items);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _peso(double amount) => formatPesoAmount(amount);

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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      color: const Color(0xFF8B6757),
                      size: size >= 64 ? 20 : 17,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'PHOTO',
                      style: TextStyle(
                        color: Color(0xFF8B6757),
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              )
            : SizedNetworkImage(
                url: imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: const Color(0xFFF3E9E2),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        color: Color(0xFF8B6757),
                        size: 20,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'PHOTO',
                        style: TextStyle(
                          color: Color(0xFF8B6757),
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _offerPhotoTile({required String? imagePath, required String label}) {
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _productThumbnail(imagePath, size: 56),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF776B65),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        : <Map<String, dynamic>>[];
    final Set<String> previewItemKeys = <String>{};
    void addPreviewItem(dynamic value) {
      if (value is! Map) return;
      final Map<String, dynamic> item = Map<String, dynamic>.from(value);
      final String key =
          (item['id'] ??
                  item['variant_id'] ??
                  item['product_id'] ??
                  item['product_name'] ??
                  item['name'] ??
                  item.hashCode)
              .toString();
      if (previewItemKeys.add(key)) previewItems.add(item);
    }

    if (!isBundle) {
      addPreviewItem(buyItem);
      for (final item in WorkspaceMobileService.maps(offer['preview_items'])) {
        addPreviewItem(item);
      }
      for (final key in const <String>[
        'buy_variant',
        'qualifying_item',
        'qualifying_product',
        'buy_product',
        'product_to_buy',
        'eligible_product',
        'reward_item',
        'reward_product',
        'reward_variant',
        'gift_item',
        'gift_product',
      ]) {
        addPreviewItem(offer[key]);
      }
      for (final key in const <String>[
        'rewards',
        'reward_items',
        'reward_variants',
        'gifts',
      ]) {
        for (final item in WorkspaceMobileService.maps(offer[key])) {
          addPreviewItem(item);
        }
      }
      for (final item in rewards) {
        addPreviewItem(item);
      }
    }
    final List<Map<String, dynamic>> previewComponents =
        WorkspaceMobileService.maps(offer['preview_components']);
    final List<Map<String, dynamic>> bundleItems = previewComponents.isNotEmpty
        ? List<Map<String, dynamic>>.from(previewComponents)
        : List<Map<String, dynamic>>.from(components);
    if (bundleItems.isEmpty) {
      for (final key in const <String>['bundle_items', 'items', 'products']) {
        bundleItems.addAll(WorkspaceMobileService.maps(offer[key]));
        if (bundleItems.isNotEmpty) break;
      }
    }
    if (bundleItems.isEmpty && buyItem != null) {
      bundleItems.add(buyItem);
    }

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
        'product_image',
        'image_url',
        'product_image_url',
        'image_path',
        'file_path',
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

      final dynamic variants = item['variants'];
      if (variants is List) {
        for (final dynamic variant in variants) {
          if (variant is Map) {
            final String path = productImage(
              Map<String, dynamic>.from(variant),
            );
            if (path.isNotEmpty) return path;
          }
        }
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

    Widget bundlePhotoTile(Map<String, dynamic> item) {
      return SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _productThumbnail(productImage(item), size: 64),
            const SizedBox(height: 4),
            Text(
              productName(item, fallback: 'Bundle item'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF776B65),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      );
    }

    final List<Map<String, dynamic>> bundlePhotoSources =
        List<Map<String, dynamic>>.from(bundleItems);
    if (bundlePhotoSources.isEmpty && buyItem != null) {
      bundlePhotoSources.add(buyItem);
    }
    if (bundlePhotoSources.isEmpty && productImage(offer).isNotEmpty) {
      bundlePhotoSources.add(offer);
    }
    if (isBundle && bundlePhotoSources.isEmpty) {
      bundlePhotoSources.add(<String, dynamic>{'name': 'Bundle item'});
    }

    final Map<String, Map<String, dynamic>> bundlePhotos =
        <String, Map<String, dynamic>>{};
    final Map<String, bool> bundlePhotoAvailability = <String, bool>{};
    for (int index = 0; index < bundlePhotoSources.length; index++) {
      final Map<String, dynamic> component = bundlePhotoSources[index];
      final dynamic rawVariant = component['variant'];
      final Map<String, dynamic> variant = rawVariant is Map
          ? Map<String, dynamic>.from(rawVariant)
          : <String, dynamic>{};
      final String choiceGroup = (component['choice_group'] ?? '').toString();
      final String groupKey = choiceGroup.isNotEmpty
          ? 'choice:$choiceGroup'
          : 'component:${component['id'] ?? index}';
      final int quantity =
          int.tryParse((component['quantity'] ?? 1).toString()) ?? 1;
      final int stock = int.tryParse((variant['stock'] ?? '').toString()) ?? 0;
      final bool available = stock >= quantity;
      if (!bundlePhotos.containsKey(groupKey) ||
          (available && bundlePhotoAvailability[groupKey] != true)) {
        bundlePhotos[groupKey] = component;
        bundlePhotoAvailability[groupKey] = available;
      }
    }
    final List<Map<String, dynamic>> bundlePhotoItems = bundlePhotos.values
        .toList(growable: false);
    Map<String, dynamic>? previewItemWithRole(String role) {
      for (final Map<String, dynamic> item in previewItems) {
        if ((item['role'] ?? '').toString().toUpperCase() == role) return item;
      }
      return null;
    }

    final Map<String, dynamic>? firstPreviewItem = previewItems.isNotEmpty
        ? previewItems.first
        : null;
    final bool firstPreviewIsReward =
        (firstPreviewItem?['role'] ?? '').toString().toUpperCase() == 'REWARD';
    final Map<String, dynamic>? qualifyingPhotoItem =
        buyItem ??
        previewItemWithRole('QUALIFYING') ??
        (firstPreviewIsReward ? null : firstPreviewItem);
    final Map<String, dynamic>? rewardPhotoItem =
        previewItemWithRole('REWARD') ??
        (previewItems.length > 1 ? previewItems[1] : null) ??
        (firstPreviewIsReward ? firstPreviewItem : null);
    final Widget photoPanel = SizedBox(
      width: 80,
      child: isBundle
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (
                  int index = 0;
                  index < bundlePhotoItems.length && index < 3;
                  index++
                ) ...[
                  bundlePhotoTile(bundlePhotoItems[index]),
                  if (index < bundlePhotoItems.length - 1 && index < 2)
                    const SizedBox(height: 8),
                ],
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _offerPhotoTile(
                  imagePath: qualifyingPhotoItem == null
                      ? null
                      : productImage(qualifyingPhotoItem),
                  label: 'Qualifying item',
                ),
                const SizedBox(height: 8),
                _offerPhotoTile(
                  imagePath: rewardPhotoItem == null
                      ? null
                      : productImage(rewardPhotoItem),
                  label: 'Free gift',
                ),
              ],
            ),
    );

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
          Row(
            crossAxisAlignment: isBundle
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              photoPanel,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            const TextSpan(
                              text: 'Get all listed items together for ',
                            ),
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
                                : ' at ' +
                                      discount.toStringAsFixed(0) +
                                      '% off.'),
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.35,
                        ),
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
                    if (!isBundle &&
                        int.tryParse(
                              offer['max_per_buyer']?.toString() ?? '',
                            ) !=
                            null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Limit ' +
                            offer['max_per_buyer'].toString() +
                            ' redemption(s) per buyer.',
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (isBundle && bundleItems.isNotEmpty) ...[
            const SizedBox(height: 9),
            for (final item in bundleItems)
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
                          ? (isBundle ? 'Adding...' : 'Starting checkout...')
                          : canAdd
                          ? (isBundle ? 'Add Bundle to Cart' : 'Buy Now')
                          : (maximum == 0
                                ? (isBundle
                                      ? 'Bundle limit reached'
                                      : 'Offer limit reached')
                                : (isBundle
                                      ? 'Bundle unavailable'
                                      : 'Reward unavailable')),
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
                    ? 'See what qualifies, choose a reward variation, and check out the qualifying item and reward together.'
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
                'Offer eligibility, stock, and reward prices are confirmed at checkout.',
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
