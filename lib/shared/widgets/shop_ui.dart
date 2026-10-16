import 'package:flutter/material.dart';

import '../../core/theme/shop_colors.dart';
import 'glass_surface.dart';

export '../../core/theme/shop_colors.dart';
export 'glass_surface.dart';

class ShopPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const ShopPageHeader({super.key, required this.title, this.subtitle, this.onBack, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (onBack != null) ...[
          GlassIconButton(icon: Icons.arrow_back_rounded, label: 'Back', onPressed: onBack),
          const SizedBox(width: 12),
        ],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: colors.onSurface, fontSize: 23, height: 1.15, letterSpacing: -.6, fontWeight: FontWeight.w700)),
          if (subtitle?.isNotEmpty == true) ...[
            const SizedBox(height: 5),
            Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurface.withValues(alpha: .6), fontSize: 12, height: 1.4)),
          ],
        ])),
        for (final action in actions) ...[const SizedBox(width: 8), action],
      ]),
    );
  }
}

class ShopSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ShopSectionTitle({super.key, required this.title, this.subtitle, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: colors.onSurface, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.5, height: 1.2)),
        if (subtitle?.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: TextStyle(color: colors.onSurface.withValues(alpha: .6), fontSize: 12, height: 1.5)),
        ],
      ])),
      if (actionLabel != null) TextButton(
        onPressed: onAction,
        child: Text(actionLabel!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

class ShopProductCard extends StatelessWidget {
  final Widget image;
  final String name;
  final String? category;
  final String? seller;
  final double price;
  final double? originalPrice;
  final double? rating;
  final int soldCount;
  final bool outOfStock;
  final bool wishlisted;
  final bool wishlistLoading;
  final VoidCallback? onTap;
  final VoidCallback? onWishlist;

  const ShopProductCard({
    super.key, required this.image, required this.name, required this.price,
    this.category, this.seller, this.originalPrice, this.rating, this.soldCount = 0,
    this.outOfStock = false, this.wishlisted = false, this.wishlistLoading = false,
    this.onTap, this.onWishlist,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final discounted = originalPrice != null && originalPrice! > price && originalPrice! > 0;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(23),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(aspectRatio: 1, child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: colors.surfaceContainerHighest, child: image),
                if (discounted) Positioned(left: 9, top: 9, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: ShopColors.accent, borderRadius: BorderRadius.circular(9)),
                  child: Text('-${((originalPrice! - price) / originalPrice! * 100).round()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                )),
                if (onWishlist != null) Positioned(right: 7, top: 7, child: Semantics(
                  button: true, toggled: wishlisted, label: wishlisted ? 'Remove from wishlist' : 'Save to wishlist',
                  child: Material(
                    color: colors.surface.withValues(alpha: .93), shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: wishlistLoading ? null : onWishlist,
                      iconSize: 20,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      icon: wishlistLoading
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(wishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: colors.primary),
                    ),
                  ),
                )),
                if (outOfStock) Positioned(bottom: 8, left: 8, right: 8, child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .65), borderRadius: BorderRadius.circular(9)),
                  child: const Text('Out of stock', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                )),
              ])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 7, 13, 15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (category?.isNotEmpty == true) ...[
                Text(category!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurface.withValues(alpha: .58), fontSize: 10.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 5),
              ],
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurface, fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600)),
              if (seller?.isNotEmpty == true) ...[
                const SizedBox(height: 5),
                Text(seller!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurface.withValues(alpha: .58), fontSize: 10.5)),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 3, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('₱${price.toStringAsFixed(2)}', style: TextStyle(color: colors.primary, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                if (discounted) Text('₱${originalPrice!.toStringAsFixed(2)}',
                  style: TextStyle(color: colors.onSurface.withValues(alpha: .45), fontSize: 10, decoration: TextDecoration.lineThrough)),
              ]),
              const SizedBox(height: 9),
              Wrap(spacing: 5, runSpacing: 3, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (rating != null) ...[
                  const Icon(Icons.star_rounded, color: Color(0xFFC18A34), size: 14),
                  Text(rating!.toStringAsFixed(1), style: TextStyle(color: colors.onSurface, fontSize: 10.5, fontWeight: FontWeight.w600)),
                  Text('·', style: TextStyle(color: colors.onSurface.withValues(alpha: .4))),
                ],
                Text('$soldCount sold', style: TextStyle(color: colors.onSurface.withValues(alpha: .55), fontSize: 10.5)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
