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

  const ShopPageHeader({super.key, required this.title, this.subtitle,
    this.onBack, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: colors.onSurface, fontSize: 24,
          height: 1.2, letterSpacing: -.5, fontWeight: FontWeight.w800)),
      if (subtitle?.isNotEmpty == true) ...[
        const SizedBox(height: 5),
        Text(subtitle!, style: TextStyle(color: colors.onSurfaceVariant,
            fontSize: 13, height: 1.45)),
      ],
    ]);
    return ColoredBox(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 390 && actions.isNotEmpty ||
              MediaQuery.textScalerOf(context).scale(14) > 20;
          final controls = Wrap(spacing: 8, runSpacing: 8, children: actions);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (onBack != null) ...[
                GlassIconButton(icon: Icons.arrow_back_rounded,
                    label: 'Back', onPressed: onBack),
                const SizedBox(width: 12),
              ],
              if (!stacked) Expanded(child: heading) else const Spacer(),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(flex: stacked ? 4 : 1, child: controls),
              ],
            ]),
            if (stacked) ...[const SizedBox(height: 14), heading],
          ]);
        }),
      ),
    );
  }
}

class ShopSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ShopSectionTitle({super.key, required this.title, this.subtitle,
    this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: colors.onSurface, fontSize: 21,
          fontWeight: FontWeight.w800, letterSpacing: -.4, height: 1.25)),
      if (subtitle?.isNotEmpty == true) ...[
        const SizedBox(height: 6),
        Text(subtitle!, style: TextStyle(color: colors.onSurfaceVariant,
            fontSize: 13, height: 1.45)),
      ],
    ]);
    final action = actionLabel == null ? null : TextButton.icon(
      onPressed: onAction,
      style: TextButton.styleFrom(minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: colors.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
      label: Text(actionLabel!),
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 350 || MediaQuery.textScalerOf(context).scale(14) > 20) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [copy, if (action != null) action]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: copy),
        if (action != null) ...[const SizedBox(width: 12), action],
      ]);
    });
  }
}

/// Natural card heights keep long names and larger text readable.
int shopGridColumns(BuildContext context, double width, {int maxColumns = 4}) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  final minimum = 150 * scale.clamp(1.0, 1.8);
  return ((width + 12) / (minimum + 12)).floor().clamp(1, maxColumns);
}

class ShopSliverGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int maxColumns;

  const ShopSliverGrid({super.key, required this.itemCount,
    required this.itemBuilder, this.maxColumns = 4});

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final columns = shopGridColumns(context, constraints.crossAxisExtent,
          maxColumns: maxColumns);
      return SliverList(delegate: SliverChildBuilderDelegate((context, row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (int column = 0; column < columns; column++) ...[
              if (column > 0) const SizedBox(width: 12),
              Expanded(child: row * columns + column < itemCount
                  ? itemBuilder(context, row * columns + column)
                  : const SizedBox.shrink()),
            ],
          ]),
        );
      }, childCount: (itemCount / columns).ceil()));
    },
  );
}

class ShopProductCard extends StatelessWidget {
  final Widget image;
  /// Aspect ratio used to lay out the product image.
  final double imageAspectRatio;
  final String name;
  final String? category;
  final String? seller;
  final double price;
  final double? originalPrice;
  final String? priceLabel;
  final double? rating;
  final int soldCount;
  final bool outOfStock;
  final String? availabilityLabel;
  final bool wishlisted;
  final bool wishlistLoading;
  final VoidCallback? onTap;
  final VoidCallback? onSellerTap;
  final VoidCallback? onWishlist;
  final Widget? footer;

  const ShopProductCard({
    super.key,
    required this.image,
    required this.name,
    this.imageAspectRatio = 1.0,
    required this.price,
    this.category,
    this.seller,
    this.originalPrice,
    this.priceLabel,
    this.rating,
    this.soldCount = 0,
    this.outOfStock = false,
    this.availabilityLabel,
    this.wishlisted = false,
    this.wishlistLoading = false,
    this.onTap,
    this.onSellerTap,
    this.onWishlist,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final discounted = originalPrice != null && originalPrice! > price && originalPrice! > 0;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.outline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(7),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(aspectRatio: imageAspectRatio, child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: colors.surfaceContainerHighest, child: image),
                if (discounted) Positioned(left: 8, top: 8, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(color: ShopColors.accent,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('-${((originalPrice! - price) / originalPrice! * 100).round()}%',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w700)),
                )),
                if (onWishlist != null) Positioned(right: 4, top: 4,
                  child: Semantics(toggled: wishlisted, child: Material(
                    color: colors.surface, shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: wishlisted ? 'Remove from wishlist' : 'Save to wishlist',
                      onPressed: wishlistLoading ? null : onWishlist,
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      iconSize: 23,
                      icon: wishlistLoading
                          ? const SizedBox.square(dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(wishlisted ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded, color: colors.primary),
                    ),
                  )),
                ),
                if (outOfStock || availabilityLabel != null)
                  Positioned(bottom: 8, left: 8, right: 8, child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: ShopColors.accentDark,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(availabilityLabel ?? 'Out of stock',
                        textAlign: TextAlign.center, style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  )),
              ])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (category?.isNotEmpty == true) ...[
                Text(category!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 5),
              ],
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurface, fontSize: 14,
                      height: 1.4, fontWeight: FontWeight.w700)),
              if (seller?.isNotEmpty == true) ...[
                const SizedBox(height: 5),
                Semantics(
                  button: onSellerTap != null,
                  label: onSellerTap == null ? seller : 'View $seller store',
                  child: InkWell(
                    onTap: onSellerTap,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        seller!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onSellerTap == null
                              ? colors.onSurfaceVariant
                              : colors.primary,
                          fontSize: 12,
                          decoration: onSellerTap == null
                              ? TextDecoration.none
                              : TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 7, runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(priceLabel ?? formatPesoAmount(price), style: TextStyle(
                    color: colors.primary, fontSize: 18, fontWeight: FontWeight.w800,
                    letterSpacing: -.3)),
                if (discounted) Text(formatPesoAmount(originalPrice!),
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12,
                        decoration: TextDecoration.lineThrough)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 5, runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (rating != null) ...[
                  const Icon(Icons.star_rounded, color: Color(0xFF956313), size: 16),
                  Text(rating!.toStringAsFixed(1), style: TextStyle(
                      color: colors.onSurface, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('·', style: TextStyle(color: colors.onSurfaceVariant)),
                ],
                Text('$soldCount sold', style: TextStyle(
                    color: colors.onSurfaceVariant, fontSize: 12)),
              ]),
              if (footer != null) ...[const SizedBox(height: 12), footer!],
            ]),
          ),
        ]),
      ),
    );
  }
}

String formatPesoAmount(num value) {
  final bool negative = value < 0;
  final List<String> parts = value.abs().toStringAsFixed(2).split('.');
  final String whole = parts.first;
  final StringBuffer grouped = StringBuffer();
  for (int index = 0; index < whole.length; index++) {
    if (index > 0 && (whole.length - index) % 3 == 0) {
      grouped.write(',');
    }
    grouped.write(whole[index]);
  }
  return '₱${negative ? '-' : ''}${grouped.toString()}.${parts.last}';
}

class ShopEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ShopEmptyState({super.key, required this.icon, required this.title,
    required this.description, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(28)),
          child: Icon(icon, color: colors.primary, size: 36)),
        const SizedBox(height: 24),
        Text(title, textAlign: TextAlign.center, style: TextStyle(
            color: colors.onSurface, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(description, textAlign: TextAlign.center, style: TextStyle(
            color: colors.onSurfaceVariant, fontSize: 14, height: 1.5)),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: onAction,
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              iconAlignment: IconAlignment.end, label: Text(actionLabel!)),
        ],
      ]),
    );
  }
}
