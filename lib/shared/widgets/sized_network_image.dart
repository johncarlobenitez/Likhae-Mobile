import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/shop_colors.dart';

/// Reuses the existing disk cache and bounds decoded image memory by the
/// display size. Buckets avoid a new memory-cache entry for tiny size changes.
class SizedNetworkImage extends StatelessWidget {
  const SizedNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.iconSize = 36,
  });

  final String url;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final ratio = MediaQuery.devicePixelRatioOf(context);
      int pixels(double logical) =>
          ((logical * ratio / 64).ceil() * 64).clamp(64, 2048).toInt();
      final width = pixels(
        constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width,
      );
      final height = constraints.hasBoundedHeight
          ? pixels(constraints.maxHeight)
          : null;
      return Image(
        image: ResizeImage(
          CachedNetworkImageProvider(url),
          width: width,
          height: height,
          policy: ResizeImagePolicy.fit,
        ),
        fit: fit,
        frameBuilder: (context, child, frame, synchronous) =>
            synchronous || frame != null
            ? child
            : const Center(child: Icon(Icons.image_outlined,
                size: 28, color: ShopColors.faint)),
        errorBuilder: (context, error, stack) => Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: ShopColors.faint,
            size: iconSize,
          ),
        ),
      );
    },
  );
}
