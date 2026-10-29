import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:likhae/features/buyer/orders/orders_screen.dart';

Future<void> _fillReturnForm(
  WidgetTester tester, {
  required String issue,
  required String reason,
  required String refundMethod,
  required String details,
}) async {
  final Finder itemCheckbox = find.byType(Checkbox).first;
  await tester.ensureVisible(itemCheckbox);
  await tester.tap(itemCheckbox);
  await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
  await tester.pumpAndSettle();
  await tester.tap(find.text(issue).last);
  await tester.pumpAndSettle();

  await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text(reason).last);
  await tester.pumpAndSettle();

  await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
  await tester.pumpAndSettle();
  await tester.tap(find.text(refundMethod).last);
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byType(TextFormField).at(0),
    'buyer@example.test',
  );
  await tester.enterText(find.byType(TextFormField).at(1), details);
  final Finder addEvidenceButton = find.byKey(
    const ValueKey<String>('buyer-return-add-evidence'),
  );
  await tester.ensureVisible(addEvidenceButton);
  await tester.tap(addEvidenceButton);
  await tester.pumpAndSettle();
  expect(find.byType(FutureBuilder<List<int>>), findsOneWidget);
  for (int index = 0; index < 2; index++) {
    final Finder consent = find.byType(CheckboxListTile).at(index);
    await tester.ensureVisible(consent);
    await tester.tap(consent);
  }
  await tester.pumpAndSettle();
  expect(
    tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .map((CheckboxListTile tile) => tile.value),
    <bool?>[true, true],
  );
  expect(
    tester
        .widgetList<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .map((DropdownButtonFormField<String> field) => field.initialValue)
        .toList(),
    <String?>[
      issue == 'Received incorrect item(s)' ? 'INCORRECT' : 'DEFECTIVE',
      reason,
      refundMethod == 'Cash refund' ? 'cash' : 'original_payment_method',
    ],
  );
  expect(
    tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .map((TextFormField field) => field.controller!.text),
    <String>['buyer@example.test', details],
  );
  expect(
    tester.widgetList<Checkbox>(find.byType(Checkbox)).first.value,
    isTrue,
  );
}

List<XFile> _returnEvidence() => <XFile>[
  XFile.fromData(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==',
    ),
    name: 'evidence.png',
    path: 'evidence.png',
  ),
];

void _useTallTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  testWidgets('return form submits its issue, reason, items, and evidence', (
    WidgetTester tester,
  ) async {
    _useTallTestSurface(tester);
    BuyerOrderReturnRequest? submittedRequest;
    const BuyerOrderData order = BuyerOrderData(
      id: 'order-return-success',
      status: 'completed',
      backendStatus: 'completed',
      statusLabel: 'Completed',
      payment: 'Cash on Delivery',
      products: <BuyerOrderProductData>[
        BuyerOrderProductData(
          id: 'order-return-success-item',
          name: 'Sample product',
          price: 100,
          quantity: 1,
        ),
      ],
      total: 100,
      buyerName: 'Buyer',
      shippingAddress: 'Sample address',
      isPreview: false,
      allowReturnRequest: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OrdersScreen(
          orders: const <BuyerOrderData>[order],
          showProductPreviewWhenEmpty: false,
          initialMode: BuyerOrdersMode.returnRequest,
          selectedOrderId: order.id,
          onSubmitReturnRequest: (BuyerOrderReturnRequest request) async {
            submittedRequest = request;
            return null;
          },
          pickReturnEvidence: () async => _returnEvidence(),
        ),
      ),
    );

    const String details = 'The item delivered is different from my order.';
    await _fillReturnForm(
      tester,
      issue: 'Received incorrect item(s)',
      reason: 'Wrong product',
      refundMethod: 'Cash refund',
      details: details,
    );
    await tester.ensureVisible(find.text('Submit Request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();

    final List<String?> snackbars = tester
        .widgetList<SnackBar>(find.byType(SnackBar))
        .map((SnackBar snackBar) => (snackBar.content as Text).data)
        .toList();
    expect(
      submittedRequest,
      isNotNull,
      reason: 'Visible validation messages: $snackbars',
    );
    expect(submittedRequest!.order.id, order.id);
    expect(submittedRequest!.issueCategory, 'INCORRECT');
    expect(submittedRequest!.issueReason, 'Wrong product');
    expect(submittedRequest!.refundMethod, 'cash');
    expect(submittedRequest!.description, details);
    expect(submittedRequest!.quantitiesByItem, <String, int>{
      'order-return-success-item': 1,
    });
    expect(submittedRequest!.evidence, hasLength(1));
    expect(find.text('Return / Refund Requested'), findsOneWidget);
  });

  testWidgets('return submission errors remain visible in the form', (
    WidgetTester tester,
  ) async {
    _useTallTestSurface(tester);
    const BuyerOrderData order = BuyerOrderData(
      id: 'order-return-1',
      status: 'completed',
      backendStatus: 'completed',
      statusLabel: 'Completed',
      payment: 'Cash on Delivery',
      products: <BuyerOrderProductData>[
        BuyerOrderProductData(
          id: 'order-return-item-1',
          name: 'Sample product',
          price: 100,
          quantity: 1,
        ),
      ],
      total: 100,
      buyerName: 'Buyer',
      shippingAddress: 'Sample address',
      isPreview: false,
      allowReturnRequest: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OrdersScreen(
          orders: const <BuyerOrderData>[order],
          showProductPreviewWhenEmpty: false,
          initialMode: BuyerOrdersMode.returnRequest,
          selectedOrderId: order.id,
          onSubmitReturnRequest: (BuyerOrderReturnRequest request) async {
            throw Exception('The backend rejected this request.');
          },
          pickReturnEvidence: () async => _returnEvidence(),
        ),
      ),
    );

    await _fillReturnForm(
      tester,
      issue: 'Product is defective / does not work',
      reason: 'Product is defective upon arrival',
      refundMethod: 'Original payment method',
      details: 'The item arrived damaged and cannot be used.',
    );
    await tester.ensureVisible(find.text('Submit Request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();

    expect(find.text('Request not submitted'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      'The backend rejected this request.',
    );
  });

  testWidgets('review form collects product and rider feedback', (
    WidgetTester tester,
  ) async {
    BuyerOrderReviewRequest? submittedReview;
    const BuyerOrderData order = BuyerOrderData(
      id: 'order-1',
      status: 'completed',
      backendStatus: 'completed',
      statusLabel: 'Completed',
      payment: 'Cash on Delivery',
      products: <BuyerOrderProductData>[
        BuyerOrderProductData(
          id: 'order-item-1',
          productId: 25,
          name: 'Sample product',
          price: 100,
          quantity: 1,
        ),
      ],
      total: 100,
      buyerName: 'Buyer',
      shippingAddress: 'Sample address',
      isPreview: false,
      allowReview: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OrdersScreen(
          orders: const <BuyerOrderData>[order],
          showProductPreviewWhenEmpty: false,
          initialMode: BuyerOrdersMode.details,
          selectedOrderId: order.id,
          onSubmitProductReview: (BuyerOrderReviewRequest request) async {
            submittedReview = request;
          },
        ),
      ),
    );

    await tester.tap(find.text('Rate & Review'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Product rating'), findsOneWidget);
    expect(find.textContaining('Delivery rider rating'), findsOneWidget);
    expect(find.text('Rider review (optional)'), findsOneWidget);
    expect(find.text('Add product photos'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('3 stars').first);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Delivery was quick.',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'The product is great.',
    );
    await tester.ensureVisible(find.text('Submit Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Review'));
    await tester.pumpAndSettle();

    expect(submittedReview, isNotNull);
    expect(submittedReview!.rating, 3);
    expect(submittedReview!.riderRating, 5);
    expect(submittedReview!.riderReview, 'Delivery was quick.');
    expect(submittedReview!.review, 'The product is great.');
    expect(submittedReview!.photos, isEmpty);
    expect(find.text('Update Review'), findsOneWidget);
    expect(find.text('The product is great.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Updated product review.',
    );
    await tester.ensureVisible(find.text('Update Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Review'));
    await tester.pumpAndSettle();

    expect(submittedReview!.rating, 3);
    expect(submittedReview!.review, 'Updated product review.');
  });
}
