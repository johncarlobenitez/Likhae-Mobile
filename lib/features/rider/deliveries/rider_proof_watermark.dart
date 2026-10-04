import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;

class RiderProofWatermark {
  static Future<Position> requireCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Turn on location services to capture delivery proof.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is required to watermark delivery proof.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  static Future<String> stamp({
    required String imagePath,
    required String riderName,
    required DateTime capturedAt,
    required Position position,
  }) async {
    final String name = riderName.trim();
    if (name.isEmpty) {
      throw Exception('Unable to load the rider name for the watermark.');
    }

    final img.Image? decoded = img.decodeImage(
      await File(imagePath).readAsBytes(),
    );
    if (decoded == null) {
      throw const FormatException('Unable to read the captured photo.');
    }

    final img.Image image = img.bakeOrientation(decoded);
    final img.BitmapFont font = image.width < 640 ? img.arial14 : img.arial24;
    final int padding = image.width < 640 ? 10 : 18;
    final int maxTextWidth = image.width - padding * 2;
    final List<String> lines = <String>[
      'DATE & TIME: ${_formatDateTime(capturedAt)}',
      'GPS: ${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)}',
      ..._wrapText('RIDER: $name', font, maxTextWidth),
    ];

    final int lineHeight = font.lineHeight;
    final int bandHeight = (lines.length * lineHeight) + (padding * 2);
    final int bandTop = image.height - bandHeight;
    img.fillRect(
      image,
      x1: 0,
      y1: bandTop,
      x2: image.width - 1,
      y2: image.height - 1,
      color: img.ColorRgba8(0, 0, 0, 185),
    );

    int textY = bandTop + padding;
    for (final String line in lines) {
      img.drawString(
        image,
        line,
        font: font,
        x: padding,
        y: textY,
        color: img.ColorRgb8(255, 255, 255),
      );
      textY += lineHeight;
    }

    final Directory outputDirectory = await Directory.systemTemp.createTemp(
      'likhae_delivery_proof_',
    );
    final File output = File(
      '${outputDirectory.path}${Platform.pathSeparator}proof.jpg',
    );
    await output.writeAsBytes(img.encodeJpg(image, quality: 85), flush: true);
    return output.path;
  }

  static List<String> _wrapText(
    String text,
    img.BitmapFont font,
    int maxWidth,
  ) {
    final List<String> lines = <String>[];
    String currentLine = '';

    for (final String word in text.split(RegExp(r'\s+'))) {
      final String candidate = currentLine.isEmpty
          ? word
          : '$currentLine $word';
      if (currentLine.isNotEmpty && _textWidth(candidate, font) > maxWidth) {
        lines.add(currentLine);
        currentLine = word;
      } else {
        currentLine = candidate;
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    return lines;
  }

  static int _textWidth(String text, img.BitmapFont font) {
    return text.codeUnits.fold<int>(0, (int width, int codeUnit) {
      return width + (font.characters[codeUnit]?.xAdvance ?? font.base ~/ 2);
    });
  }

  static String _formatDateTime(DateTime value) {
    final DateTime local = value.toLocal();
    final String year = local.year.toString().padLeft(4, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    final String second = local.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }
}
