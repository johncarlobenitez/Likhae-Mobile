import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders the image data URI returned by Laravel's attendance QR endpoint.
/// Laravel may return SVG for web requests and PNG for mobile API requests.
class RiderAttendanceQrImage extends StatelessWidget {
  final String dataUri;
  final double size;

  const RiderAttendanceQrImage({
    super.key,
    required this.dataUri,
    this.size = 230,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final int comma = dataUri.indexOf(',');
      if (comma < 0 || !dataUri.startsWith('data:')) {
        return _error();
      }

      final String metadata = dataUri.substring(5, comma).toLowerCase();
      final String encoded = dataUri.substring(comma + 1);
      final Uint8List bytes = metadata.contains(';base64')
          ? Uint8List.fromList(
              base64.decode(
                base64.normalize(encoded.replaceAll(RegExp(r'\s'), '')),
              ),
            )
          : Uint8List.fromList(Uri.decodeComponent(encoded).codeUnits);
      final String mimeType = metadata.split(';').first;

      if (mimeType == 'image/svg+xml') {
        return SvgPicture.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => SizedBox(
            width: size,
            height: size,
            child: const Center(child: CircularProgressIndicator()),
          ),
        );
      }

      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _error(),
      );
    } catch (_) {
      return _error();
    }
  }

  Widget _error() => SizedBox(
    width: size,
    height: size,
    child: const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'QR image could not be read. Refresh the code and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF5B2828), fontSize: 12),
        ),
      ),
    ),
  );
}
