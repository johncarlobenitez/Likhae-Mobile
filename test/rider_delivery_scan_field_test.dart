import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/rider/deliveries/rider_delivery_scan_field.dart';
import 'package:likhae/features/rider/scanner/rider_parcel_scan_result.dart';

void main() {
  testWidgets(
    'manual entry only confirms the assigned parcel and clears a prior match',
    (tester) async {
      RiderParcelScanResult? scan;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiderDeliveryScanField(
              expectedTrackingCode: 'TRK-12',
              onChanged: (value) => scan = value,
            ),
          ),
        ),
      );
      expect(scan, isNull);
      await tester.enterText(find.byType(TextField), ' TRK-12 ');
      expect(scan?.code, 'TRK-12');
      expect(scan?.method, 'MANUAL');
      await tester.enterText(find.byType(TextField), 'OTHER');
      await tester.pump();
      expect(scan, isNull);
      expect(
        find.text('This code does not match the assigned parcel.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(scan, isNull);
    },
  );
}
