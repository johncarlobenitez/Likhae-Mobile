import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/orders/orders_screen.dart';

void main() {
  testWidgets('return form submits its selected type, reason, and details', (
    WidgetTester tester,
  ) async {
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
          },
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refund only').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wrong product').last);
    await tester.pumpAndSettle();

    const String details = 'The item delivered is different from my order.';
    await tester.enterText(find.byType(TextFormField).first, details);
    await tester.ensureVisible(find.text('Submit Request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();

    expect(submittedRequest, isNotNull);
    expect(submittedRequest!.order.id, order.id);
    expect(submittedRequest!.requestType, 'Refund only');
    expect(submittedRequest!.reason, 'Wrong product');
    expect(submittedRequest!.details, details);
    expect(find.text('Return / Refund Requested'), findsOneWidget);
  });

  testWidgets('return submission errors remain visible in the form', (
    WidgetTester tester,
  ) async {
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
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return and refund').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Defective item').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'The item arrived damaged and cannot be used.',
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
