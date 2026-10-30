import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/rider/pickups/rider_pickup_batch_details_screen.dart';
import 'package:likhae/features/rider/pickups/rider_pickup_details_screen.dart';
import 'package:likhae/features/rider/pickups/rider_pickups_screen.dart';
import 'package:likhae/features/rider/scanner/rider_parcel_scan_result.dart';
import 'package:likhae/features/rider/transfers/rider_inter_hub_transfers_screen.dart';

RiderPickupData batch(
  String status, {
  String first = 'IN_PROGRESS',
  String second = 'IN_PROGRESS',
}) => RiderPickupData.fromApi({
  'id': 7,
  'batch_number': 'P-7',
  'status': status,
  'seller': 'Seller',
  'pickup_address': 'Seller address',
  'logistics_center': 'Hub',
  'parcel_count': 2,
  'items': [
    {'assignment_id': 11, 'tracking': 'TRK-1', 'assignment_status': first},
    {'assignment_id': 12, 'tracking': 'TRK-2', 'assignment_status': second},
  ],
});

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

void main() {
  testWidgets('batch accept, start, manual scan, not collected and finish', (
    tester,
  ) async {
    await largeViewport(tester);
    var latest = batch('LOADING');
    final actions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: RiderPickupBatchDetailsScreen(
          batch: latest,
          onReload: (_) async => latest,
          onAccept: (id) async {
            actions.add('accept:$id');
            latest = batch('READY');
          },
          onStart: (id) async {
            actions.add('start:$id');
            latest = batch('IN_PROGRESS');
          },
          onScan: (id, code, method) async {
            actions.add('scan:$id:$code:$method');
            latest = batch('IN_PROGRESS', first: 'COMPLETED');
          },
          onNotCollected:
              ({
                required batchId,
                required assignmentId,
                required reason,
              }) async {
                actions.add('not-collected:$batchId:$assignmentId:$reason');
                latest = batch(
                  'IN_PROGRESS',
                  first: 'COMPLETED',
                  second: 'REJECTED',
                );
              },
          onFinish: (id) async {
            actions.add('finish:$id');
            latest = batch(
              'EN_ROUTE_TO_HUB',
              first: 'COMPLETED',
              second: 'REJECTED',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Scan parcel barcode / QR'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Scan parcel barcode / QR'),
          )
          .onPressed,
      isNull,
    );
    await tapText(tester, 'Accept pickup batch');
    await tapText(tester, 'Start seller pickup');
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Scan parcel barcode / QR'),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.text('Finish after resolving every parcel'), findsOneWidget);
    await tapText(tester, 'Enter tracking code manually');
    await tester.enterText(find.byType(TextField), ' TRK-1 ');
    await tapText(tester, 'Verify');
    await tapText(tester, 'Not collected');
    await tester.enterText(find.byType(TextField), 'Seller unavailable');
    await tapText(tester, 'Submit reason');
    await tapText(tester, 'Finish pickup and go to hub');
    expect(actions, [
      'accept:7',
      'start:7',
      'scan:7:TRK-1:MANUAL',
      'not-collected:7:12:Seller unavailable',
      'finish:7',
    ]);
    expect(find.textContaining('Deliver 1 collected parcel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved action with failed reload blocks replay until refresh', (
    tester,
  ) async {
    await largeViewport(tester);
    var reads = 0;
    var accepts = 0;
    var recovered = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderPickupBatchDetailsScreen(
          batch: batch('LOADING'),
          onReload: (_) async {
            reads++;
            if (reads > 1 && !recovered) throw Exception('Network unavailable');
            return batch(recovered ? 'READY' : 'LOADING');
          },
          onAccept: (_) async {
            accepts++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'Accept pickup batch');
    expect(accepts, 1);
    expect(find.textContaining('Your action was saved.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Accept pickup batch'),
          )
          .onPressed,
      isNull,
    );
    recovered = true;
    await tester.tap(find.byTooltip('Refresh pickup'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start seller pickup'));
    expect(find.text('Start seller pickup'), findsOneWidget);
    expect(accepts, 1);
  });

  testWidgets('unknown batch status cannot complete pickup', (tester) async {
    await largeViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: RiderPickupBatchDetailsScreen(batch: batch('UNEXPECTED')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('No pickup action is available'),
      300,
    );
    expect(find.text('Finish pickup and go to hub'), findsNothing);
  });

  testWidgets('single pickup shows scan controls before it starts', (
    tester,
  ) async {
    await largeViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: RiderPickupDetailsScreen(
          pickup: RiderPickupData.fromApi({
            'id': 11,
            'tracking': 'TRK-1',
            'status': 'ASSIGNED',
            'seller': 'Seller',
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Scan Parcel At Seller'));
    expect(
      find.text('Start seller pickup to enable scanning.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'single pickup requires verification and sends the entered code',
    (tester) async {
      await largeViewport(tester);
      final transitions = <RiderPickupTransitionRequest>[];
      await tester.pumpWidget(
        MaterialApp(
          home: RiderPickupDetailsScreen(
            pickup: RiderPickupData.fromApi({
              'id': 11,
              'tracking': 'TRK-1',
              'status': 'ASSIGNED',
            }),
            onTransition: (request) async {
              transitions.add(request);
            },
            onVerifyTracking: (_, code) async => code == 'TRK-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Accept Pickup');
      await tapText(tester, 'Start Seller Pickup');
      expect(find.text('Confirm Picked Up'), findsNothing);
      await tester.enterText(find.byType(TextField), 'WRONG');
      await tapText(tester, 'Verify Parcel');
      expect(
        find.textContaining('does not match this pickup assignment'),
        findsOneWidget,
      );
      expect(find.text('Confirm Picked Up'), findsNothing);
      await tester.enterText(find.byType(TextField), 'TRK-1');
      await tapText(tester, 'Verify Parcel');
      expect(find.text('Confirm Picked Up'), findsOneWidget);
      // Editing a previously verified code must invalidate verification.
      await tester.enterText(find.byType(TextField), 'EDITED');
      await tester.pump();
      expect(find.text('Confirm Picked Up'), findsNothing);
      await tester.enterText(find.byType(TextField), 'TRK-1');
      await tapText(tester, 'Verify Parcel');
      await tapText(tester, 'Confirm Picked Up');
      expect(transitions.map((r) => r.status), [
        'accepted',
        'in_progress',
        'picked_up',
      ]);
      expect(transitions.last.scannedCode, 'TRK-1');
      expect(transitions.last.scanMethod, 'MANUAL');
      expect(
        find.textContaining('Pickup completed and recorded.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rejected batch scan preserves unresolved parcel and allows retry',
    (tester) async {
      await largeViewport(tester);
      var scans = 0;
      var reloads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RiderPickupBatchDetailsScreen(
            batch: batch('IN_PROGRESS'),
            onReload: (_) async {
              reloads++;
              return batch('IN_PROGRESS');
            },
            onScan: (_, code, method) async {
              scans++;
              throw Exception('Wrong waybill');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Enter tracking code manually');
      await tester.enterText(find.byType(TextField), 'WRONG');
      await tapText(tester, 'Verify');
      expect(scans, 1);
      expect(reloads, 1);
      expect(find.textContaining('Wrong waybill'), findsOneWidget);
      expect(find.text('0 of 2 parcels collected'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Scan parcel barcode / QR'),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text('Finish pickup and go to hub'), findsNothing);
    },
  );

  RiderInterHubTransferData manifest({bool canStart = true}) =>
      RiderInterHubTransferData.fromApi({
        'id': 9,
        'manifest_number': 'M-9',
        'status': 'RELEASED',
        'status_label': 'Released by hub',
        'driver_accepted_at': '2026-10-30',
        'can_start': canStart,
        'items': [
          {'id': 21, 'tracking_code': 'TRK-1'},
          {'id': 22, 'tracking_code': 'TRK-2'},
        ],
      });

  testWidgets('transfer camera scans every parcel and submits QR method', (
    tester,
  ) async {
    await largeViewport(tester);
    var scans = 0;
    var detailReads = 0;
    Map<int, String>? submitted;
    String? method;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderInterHubTransfersScreen(
          transfers: [manifest()],
          onLoadTransfer: (_) async {
            detailReads++;
            return manifest();
          },
          onScanParcel: () async =>
              RiderParcelScanResult(code: 'TRK-${++scans}', method: 'QR'),
          onStart: (id, codes, {scanMethod = 'MANUAL'}) async {
            submitted = codes;
            method = scanMethod;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'Start transport');
    await tapText(tester, 'Start transport');
    expect(find.text('Scan every parcel before starting.'), findsOneWidget);
    expect(submitted, isNull);
    for (var i = 1; i <= 2; i++) {
      await tester.tap(find.byTooltip('Scan parcel $i'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tapText(tester, 'Start transport');
    expect(detailReads, 1);
    expect(submitted, {21: 'TRK-1', 22: 'TRK-2'});
    expect(method, 'QR');
    expect(tester.takeException(), isNull);
  });

  testWidgets('transfer refuses stale manifest that is no longer released', (
    tester,
  ) async {
    await largeViewport(tester);
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderInterHubTransfersScreen(
          transfers: [manifest()],
          onLoadTransfer: (_) async => manifest(canStart: false),
          onStart: (_, codes, {scanMethod = 'MANUAL'}) async {
            starts++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'Start transport');
    expect(find.text('Scan manifest parcels'), findsNothing);
    expect(starts, 0);
    expect(find.textContaining('not ready to start'), findsOneWidget);
  });
}

Future<void> largeViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}
