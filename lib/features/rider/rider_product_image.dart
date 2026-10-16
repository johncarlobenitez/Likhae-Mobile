import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

/// Accepts the canonical API image or the first product photo in a batch.
String? riderProductImageUrl(Map<String, dynamic> row) {
  String? imageValue(dynamic value) {
    if (value is String) {
      return value.trim().isEmpty ? null : value.trim();
    }
    if (value is List) {
      for (final item in value) {
        final image = imageValue(item);
        if (image != null) return image;
      }
    }
    if (value is Map) {
      for (final key in ['url', 'image_url', 'file_path', 'path', 'src']) {
        final image = imageValue(value[key]);
        if (image != null) return image;
      }
    }
    return null;
  }

  String? findImage(Map data, int depth) {
    if (depth > 5) return null;
    for (final key in [
      'image_url',
      'product_image_url',
      'product_image',
      'image',
      'photo_url',
      'photo',
      'images',
      'image_urls',
      'thumbnail_url',
      'thumbnail',
    ]) {
      final image = imageValue(data[key]);
      if (image != null) return image;
    }
    for (final key in [
      'product',
      'products',
      'items',
      'item',
      'order',
      'shipment',
      'seller_order',
      'sellerOrder',
      'line_items',
      'lineItems',
      'details',
    ]) {
      final nested = data[key];
      if (nested is Map) {
        final image = findImage(nested, depth + 1);
        if (image != null) return image;
      } else if (nested is List) {
        for (final item in nested.whereType<Map>()) {
          final image = findImage(item, depth + 1);
          if (image != null) return image;
        }
      }
    }
    return null;
  }

  final image = findImage(row, 0);
  return image == null ? null : AppConfig.resolveMediaUrl(image);
}

class RiderProductImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String semanticLabel;

  const RiderProductImage({
    super.key,
    required this.imageUrl,
    this.size = 64,
    this.semanticLabel = 'Product photo',
  });

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.resolveMediaUrl(imageUrl);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECE4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEADCCC)),
      ),
      child: url.isEmpty
          ? const Icon(Icons.inventory_2_outlined, color: Color(0xFFA99386))
          : Image.network(
              url,
              fit: BoxFit.cover,
              semanticLabel: semanticLabel,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF561C17),
                        ),
                      ),
                    ),
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFFA99386),
              ),
            ),
    );
  }
}
