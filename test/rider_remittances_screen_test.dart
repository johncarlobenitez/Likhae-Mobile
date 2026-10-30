import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/rider/earnings/rider_remittance_models.dart';
import 'package:likhae/features/rider/earnings/rider_remittances_screen.dart';

const available = RiderRemittanceSnapshot(
  available: true,
  collections: [
    RiderCodCollection(
      id: 8,
      tracking: 'TRK-8',
      reference: 'COD-8',
      collectedAmount: 125.50,
    ),
  ],
  history: [],
);
const receipt = RiderRemittance(
  id: 3,
  reference: 'REM-3',
  status: 'SUBMITTED',
  expectedAmount: 125.50,
  submittedAmount: 125.50,
);

Future<void> selectParcel(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
  await tester.enterText(find.byType(TextField).first, '125.50');
  await tester.ensureVisible(find.text('Record cash handoff'));
}

void main() {
  testWidgets(
    'confirmed receipt survives refresh failure and prevents duplicate submission',
    (tester) async {
      final submitted = Completer<RiderRemittance>();
      var loads = 0;
      var writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RiderRemittancesScreen(
            load: () async {
              if (loads++ > 0) throw Exception('Refresh unavailable');
              return available;
            },
            submit: ({required collectionId, required amount, notes = ''}) {
              writes++;
              expect(collectionId, 8);
              expect(amount, '125.50');
              return submitted.future;
            },
          ),
        ),
      );
      await selectParcel(tester);
      await tester.tap(find.text('Record cash handoff'));
      await tester.pump();
      expect(writes, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      submitted.complete(receipt);
      await tester.pumpAndSettle();
      expect(find.text('REM-3'), findsOneWidget);
      expect(find.text('Awaiting logistics confirmation'), findsOneWidget);
      expect(find.text('Record cash handoff'), findsNothing);
      expect(writes, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('rejected remittance retains form for correction and retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderRemittancesScreen(
          load: () async => available,
          submit: ({required collectionId, required amount, notes = ''}) async {
            throw Exception('The collection is unavailable');
          },
        ),
      ),
    );
    await selectParcel(tester);
    await tester.tap(find.text('Record cash handoff'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '125.50',
    );
    expect(find.text('REM-3'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
