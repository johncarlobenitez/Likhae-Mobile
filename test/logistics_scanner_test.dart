import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:likhae/features/rider/scanner/rider_scanner_screen.dart';

void main() {
  testWidgets('logistics scanner returns a manually entered tracking code', (
    tester,
  ) async {
    Map<String, String>? receivedScan;
    final router = GoRouter(
      initialLocation: '/logistics',
      routes: [
        GoRoute(
          path: '/logistics',
          builder: (context, state) => StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () async {
                      final result = await context.push<Map<String, String>>(
                        '/logistics/scanner',
                      );
                      if (result != null) setState(() => receivedScan = result);
                    },
                    child: const Text('Open logistics scanner'),
                  ),
                  if (receivedScan case final scan?)
                    Text('${scan['scanned_code']}:${scan['scan_method']}'),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/logistics/scanner',
          builder: (context, state) => const RiderScannerScreen(
            showSignOut: false,
            returnScanDetails: true,
          ),
        ),
      ],
    );

    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open logistics scanner'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Parcel Scanner'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Manual Tracking Code'),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.enterText(find.byType(TextField), ' TRK-MOBILE-001 ');
    await tester.tap(find.text('Use Tracking Code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('TRK-MOBILE-001:MANUAL'), findsOneWidget);
  });

  testWidgets('logistics scanner returns a detected QR tracking code', (
    tester,
  ) async {
    final fakePlatform = _FakeMobileScannerPlatform();
    MobileScannerPlatform.instance = fakePlatform;
    Map<String, String>? receivedScan;
    final router = GoRouter(
      initialLocation: '/logistics',
      routes: [
        GoRoute(
          path: '/logistics',
          builder: (context, state) => StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () async {
                      final result = await context.push<Map<String, String>>(
                        '/logistics/scanner',
                      );
                      if (result != null) setState(() => receivedScan = result);
                    },
                    child: const Text('Open logistics scanner'),
                  ),
                  if (receivedScan case final scan?)
                    Text('${scan['scanned_code']}:${scan['scan_method']}'),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/logistics/scanner',
          builder: (context, state) => const RiderScannerScreen(
            showSignOut: false,
            returnScanDetails: true,
          ),
        ),
      ],
    );

    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open logistics scanner'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(fakePlatform.didStart, isTrue);

    fakePlatform.addBarcode(
      const BarcodeCapture(
        barcodes: [
          Barcode(rawValue: 'TRK-MOBILE-QR-001', format: BarcodeFormat.qrCode),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('TRK-MOBILE-QR-001:QR'), findsOneWidget);
  });

  testWidgets(
    'logistics scanner collects multiple unique barcodes per session',
    (tester) async {
      final fakePlatform = _FakeMobileScannerPlatform();
      MobileScannerPlatform.instance = fakePlatform;
      List<Map<String, String>>? receivedBatch;
      final router = GoRouter(
        initialLocation: '/logistics',
        routes: [
          GoRoute(
            path: '/logistics',
            builder: (context, state) => StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () async {
                        final result = await context
                            .push<List<Map<String, String>>>(
                              '/logistics/scanner',
                            );
                        if (result != null) {
                          setState(() => receivedBatch = result);
                        }
                      },
                      child: const Text('Open logistics scanner'),
                    ),
                    Text(
                      receivedBatch
                              ?.map((scan) => scan['scanned_code'])
                              .join(',') ??
                          '',
                    ),
                  ],
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/logistics/scanner',
            builder: (context, state) =>
                const RiderScannerScreen(showSignOut: false, multiScan: true),
          ),
        ],
      );

      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Open logistics scanner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakePlatform.didStart, isTrue);

      fakePlatform.addBarcode(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: 'TRK-BATCH-001', format: BarcodeFormat.code128),
            Barcode(rawValue: 'TRK-BATCH-002', format: BarcodeFormat.code128),
          ],
        ),
      );
      await tester.pump();
      expect(
        find.text('2 parcels captured · camera stays active'),
        findsOneWidget,
      );

      fakePlatform.addBarcode(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: 'TRK-BATCH-001', format: BarcodeFormat.code128),
            Barcode(rawValue: 'TRK-BATCH-003', format: BarcodeFormat.code128),
          ],
        ),
      );
      await tester.pump();
      expect(
        find.text('3 parcels captured · camera stays active'),
        findsOneWidget,
      );

      await tester.tap(find.text('Finish (3)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('TRK-BATCH-001,TRK-BATCH-002,TRK-BATCH-003'),
        findsOneWidget,
      );
    },
  );
}

class _FakeMobileScannerPlatform extends MobileScannerPlatform {
  final StreamController<BarcodeCapture> _barcodes =
      StreamController<BarcodeCapture>.broadcast();
  bool didStart = false;

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream =>
      Stream.value(TorchState.unavailable);

  @override
  Stream<double> get zoomScaleStateStream => Stream.value(1);

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    didStart = true;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(200, 200),
      numberOfCameras: 1,
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Widget buildCameraView() => const SizedBox.square(dimension: 100);

  void addBarcode(BarcodeCapture capture) => _barcodes.add(capture);

  @override
  Future<void> dispose() => _barcodes.close();
}
