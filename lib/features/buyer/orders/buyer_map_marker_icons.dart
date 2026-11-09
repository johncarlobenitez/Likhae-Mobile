import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/shop_ui.dart';

enum BuyerMapMarkerKind { seller, hub, buyer, rider, interHubRider }

class BuyerMapMarkerIcons {
  final Map<BuyerMapMarkerKind, Uint8List> _images = {};

  Future<Uint8List> image(BuyerMapMarkerKind kind) async {
    final cached = _images[kind];
    if (cached != null) return cached;
    final Color fill = switch (kind) {
      BuyerMapMarkerKind.seller => const Color(0xFFB56B32),
      BuyerMapMarkerKind.hub => const Color(0xFF15803D),
      BuyerMapMarkerKind.buyer => const Color(0xFF2563EB),
      BuyerMapMarkerKind.rider ||
      BuyerMapMarkerKind.interHubRider => ShopColors.accent,
    };
    final IconData icon = switch (kind) {
      BuyerMapMarkerKind.seller => Icons.storefront_rounded,
      BuyerMapMarkerKind.hub => Icons.warehouse_rounded,
      BuyerMapMarkerKind.buyer => Icons.home_rounded,
      BuyerMapMarkerKind.rider => Icons.two_wheeler_rounded,
      BuyerMapMarkerKind.interHubRider => Icons.local_shipping_rounded,
    };
    const double size = 64;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint fillPaint = Paint()..color = fill;
    final Paint outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(const Offset(size / 2, size / 2), 29, fillPaint);
    canvas.drawCircle(const Offset(size / 2, size / 2), 29, outlinePaint);
    final TextPainter glyph = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize:
              kind == BuyerMapMarkerKind.rider ||
                  kind == BuyerMapMarkerKind.interHubRider
              ? 34
              : 38,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glyph.paint(
      canvas,
      Offset((size - glyph.width) / 2, (size - glyph.height) / 2),
    );
    final ui.Image image = await recorder.endRecording().toImage(64, 64);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    final Uint8List bytes = data!.buffer.asUint8List();
    _images[kind] = bytes;
    return bytes;
  }
}
