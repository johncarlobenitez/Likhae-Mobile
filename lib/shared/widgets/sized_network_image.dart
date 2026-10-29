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
    this.headers,
    this.placeholder,
    this.errorBuilder,
    this.semanticLabel,
  });

  final String url;
  final BoxFit fit;
  final double iconSize;
  final Map<String, String>? headers;
  final Widget? placeholder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final String? semanticLabel;

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
          CachedNetworkImageProvider(url, headers: headers),
          width: width,
          height: height,
          policy: ResizeImagePolicy.fit,
        ),
        fit: fit,
        semanticLabel: semanticLabel,
        frameBuilder: (context, child, frame, synchronous) =>
            synchronous || frame != null
            ? child
            : placeholder ?? const Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 28,
                  color: ShopColors.faint,
                ),
              ),
        errorBuilder: errorBuilder ?? (context, error, stack) => Center(
          child: Icon(Icons.broken_image_outlined,
              color: ShopColors.faint, size: iconSize),
        ),
      );
    },
  );
}
