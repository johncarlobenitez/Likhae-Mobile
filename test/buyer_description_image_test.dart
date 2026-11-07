import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/features/buyer/products/product_details_screen.dart';
import 'package:likhae/shared/widgets/sized_network_image.dart';

void main() {
  const String filename = '3a3d46a2-8ef2-417f-9374-d7d2fde64365.webp';
  const String expectedImageUrl =
      'https://likhae.online/storage/sellers/7/products/42/descriptions/$filename';

  ProductDetailData productWithStoredDescriptionImage() {
    return ProductDetailData.fromApi(<String, dynamic>{
      'id': 42,
      'name': 'Gilas Pilipinas Basketball Set',
      'min_price': '1200.00',
      'seller': <String, dynamic>{'id': 7, 'business_name': 'Sports House'},
      'description':
          'The set includes one sleeveless jersey.\n'
          '[[description-image:stored:$filename]]\n'
          'Available in several sizes.',
    });
  }

  test('maps stored description image markers to media blocks', () {
    final ProductDetailData product = productWithStoredDescriptionImage();

    expect(product.descriptionBlocks, hasLength(3));
    expect(product.descriptionBlocks[0].text, contains('sleeveless jersey'));
    expect(product.descriptionBlocks[1].imageUrl, expectedImageUrl);
    expect(product.descriptionBlocks[2].text, contains('several sizes'));
    expect(
      product.descriptionBlocks.map((block) => block.text ?? '').join(),
      isNot(contains('description-image:stored')),
    );
    expect(AppConfig.resolveMediaUrl(expectedImageUrl), expectedImageUrl);
  });

  testWidgets('buyer details renders the stored description photo inline', (
    tester,
  ) async {
    final ProductDetailData product = productWithStoredDescriptionImage();
    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailsScreen(
          product: product,
          onAddToCartRequest: (_) async {},
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is SizedNetworkImage && widget.url == expectedImageUrl,
      ),
      findsAtLeastNWidgets(1),
    );
    expect(find.textContaining('description-image:stored'), findsNothing);
    expect(
      find.textContaining('The set includes one sleeveless jersey.'),
      findsAtLeastNWidgets(1),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
