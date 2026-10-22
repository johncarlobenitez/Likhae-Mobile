import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/shop_colors.dart';
import '../../../shared/widgets/sized_network_image.dart';
import 'store_screen.dart';

typedef FollowingShopsLoader = Future<List<StoreSellerData>> Function();
typedef FollowingShopSelected = void Function(StoreSellerData shop);

class FollowingShopsScreen extends StatefulWidget {
  final FollowingShopsLoader loadShops;
  final FollowingShopSelected onShopSelected;
  final VoidCallback? onBack;

  const FollowingShopsScreen({
    super.key,
    required this.loadShops,
    required this.onShopSelected,
    this.onBack,
  });

  @override
  State<FollowingShopsScreen> createState() => _FollowingShopsScreenState();
}

class _FollowingShopsScreenState extends State<FollowingShopsScreen> {
  late Future<List<StoreSellerData>> _shopsFuture;
  bool _wasCovered = false;

  @override
  void initState() {
    super.initState();
    _shopsFuture = widget.loadShops();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool isCovered = ModalRoute.of(context)?.isCurrent == false;
    if (_wasCovered && !isCovered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
    _wasCovered = isCovered;
  }

  Future<void> _refresh() async {
    final Future<List<StoreSellerData>> next = widget.loadShops();
    setState(() => _shopsFuture = next);
    try {
      await next;
    } catch (_) {
      // FutureBuilder renders the retry state from this same request.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.canvas,
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        title: const Text('Following Shops'),
      ),
      body: FutureBuilder<List<StoreSellerData>>(
        future: _shopsFuture,
        builder: (BuildContext context, AsyncSnapshot<List<StoreSellerData>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final String errorMessage = snapshot.error
                .toString()
                .replaceFirst('Exception: ', '');
            final bool endpointMissing = errorMessage
                .toLowerCase()
                .contains('api endpoint not found');
            return _FollowingShopsMessage(
              icon: Icons.cloud_off_outlined,
              title: endpointMissing
                  ? 'Server update needed'
                  : 'Could not load followed shops',
              message: endpointMissing
                  ? 'Update or restart the Laravel API, then try again.'
                  : 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: _refresh,
            );
          }

          final List<StoreSellerData> shops =
              snapshot.data ?? const <StoreSellerData>[];
          if (shops.isEmpty) {
            return _FollowingShopsMessage(
              icon: Icons.storefront_outlined,
              title: 'No followed shops yet',
              message: 'Follow a shop to find it here.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: shops.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final StoreSellerData shop = shops[index];
                return Material(
                  color: ShopColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => widget.onShopSelected(shop),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 58,
                              height: 58,
                              child: shop.avatarUrl?.trim().isNotEmpty == true
                                  ? SizedNetworkImage(
                                      url: AppConfig.resolveMediaUrl(
                                        shop.avatarUrl,
                                      ),
                                      iconSize: 24,
                                    )
                                  : const ColoredBox(
                                      color: ShopColors.accentSoft,
                                      child: Icon(
                                        Icons.storefront_outlined,
                                        color: ShopColors.accent,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shop.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: ShopColors.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (shop.location?.trim().isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    shop.location!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: ShopColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: ShopColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FollowingShopsMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _FollowingShopsMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: ShopColors.accentLight),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ShopColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ShopColors.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
