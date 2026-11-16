import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:likhae/features/rider/deliveries/rider_proof_watermark.dart';

void main() {
  test(
    'stamps rider identity without changing the captured image size',
    () async {
      final Directory sourceDirectory = await Directory.systemTemp.createTemp(
        'rider_proof_watermark_test_',
      );
      addTearDown(() => sourceDirectory.delete(recursive: true));

      final img.Image source = img.Image(width: 640, height: 480)
        ..clear(img.ColorRgb8(255, 255, 255));
      final File sourceFile = File(
        '${sourceDirectory.path}${Platform.pathSeparator}source.jpg',
      );
      await sourceFile.writeAsBytes(img.encodeJpg(source));

      final DateTime capturedAt = DateTime(2026, 10, 4, 17, 5, 4);
      final Position position = Position(
        latitude: 14.5995,
        longitude: 120.9842,
        timestamp: capturedAt,
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      Future<String> stampForRider(String name) => RiderProofWatermark.stamp(
        imagePath: sourceFile.path,
        riderName: name,
        capturedAt: capturedAt,
        position: position,
        location: 'Manila, Philippines',
      );

      final String stampedPath = await RiderProofWatermark.stamp(
        imagePath: sourceFile.path,
        riderName: 'Rider Name',
        capturedAt: capturedAt,
        position: position,
        location: 'Manila, Philippines',
      );
      final Directory stampedDirectory = File(stampedPath).parent;
      addTearDown(() => stampedDirectory.delete(recursive: true));
      final String otherRiderPath = await stampForRider('Another Rider');
      final Directory otherRiderDirectory = File(otherRiderPath).parent;
      addTearDown(() => otherRiderDirectory.delete(recursive: true));

      final img.Image? stamped = img.decodeImage(
        await File(stampedPath).readAsBytes(),
      );

      expect(stamped, isNotNull);
      expect(stamped!.width, source.width);
      expect(stamped.height, source.height);
      expect(stamped.getPixel(2, stamped.height - 2).r, lessThan(100));
      expect(
        await File(stampedPath).readAsBytes(),
        isNot(equals(await File(otherRiderPath).readAsBytes())),
      );
    },
  );
}
