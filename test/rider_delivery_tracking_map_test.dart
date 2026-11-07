import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:likhae/features/rider/deliveries/rider_delivery_tracking_screen.dart';

void main() {
  testWidgets(
    'shows the route guide when rider and buyer locations exist',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 1400));

      await tester.pumpWidget(
        const MaterialApp(
          home: RiderDeliveryTrackingScreen(
            deliveryLocation: LatLng(14.2326, 121.3648),
            riderLocation: LatLng(14.2298, 121.3599),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Route guide'), findsOneWidget);
      expect(find.text('Buyer location'), findsOneWidget);
      expect(find.text('Current rider location'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
