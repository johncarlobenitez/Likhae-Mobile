import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/api/api_client.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/features/buyer/home/home_screen.dart';
import 'package:likhae/features/buyer/products/product_details_screen.dart';
import 'package:likhae/features/buyer/products/products_screen.dart';
import 'package:likhae/services/product_service.dart';

void main() {
  group('AppConfig.resolveApiUrl', () {
    test('resolves endpoint paths against the Laravel API base URL', () {
      expect(
        AppConfig.resolveApiUrl('products'),
        'https://likhae.online/api/v1/products',
      );
      expect(
        AppConfig.resolveApiUrl('/api/v1/auth/login'),
        'https://likhae.online/api/v1/auth/login',
      );
    });
  });

  group('AppConfig.resolveMediaUrl', () {
    test('keeps full URLs unchanged', () {
      const url = 'https://cdn.example.com/products/1.jpg';
      expect(AppConfig.resolveMediaUrl(url), url);
    });

    test('resolves storage and uploads paths from the live domain root', () {
      expect(
        AppConfig.resolveMediaUrl('storage/products/1.jpg'),
        'https://likhae.online/storage/products/1.jpg',
      );
      expect(
        AppConfig.resolveMediaUrl('uploads/products/1.jpg'),
        'https://likhae.online/uploads/products/1.jpg',
      );
      expect(
        AppConfig.resolveMediaUrl('images/products/1.jpg'),
        'https://likhae.online/images/products/1.jpg',
      );
    });

    test('handles leading slash and default storage fallback', () {
      expect(
        AppConfig.resolveMediaUrl('/storage/products/2.jpg'),
        'https://likhae.online/storage/products/2.jpg',
      );
      expect(
        AppConfig.resolveMediaUrl('product.jpg'),
        'https://likhae.online/storage/product.jpg',
      );
    });
  });

  group('offline mode', () {
    test(
      'disables the API layer while layout work is being finished',
      () async {
        expect(AppConfig.apiEnabled, isFalse);

        final Response<dynamic> response = await ApiClient.get('demo');

        expect(response.statusCode, 200);
        expect(response.data, isEmpty);
      },
    );

    test(
      'returns a shuffled local product list instead of an empty feed',
      () async {
        final List<dynamic> products = await ProductService.fetchHomeProducts();

        expect(products, isNotEmpty);
        expect(products.length, greaterThanOrEqualTo(4));
      },
    );

    test('provides product rows for offline catalog screens', () async {
      final List<Map<String, dynamic>> rows =
          await ProductService.fetchProductRows();

      expect(rows, isNotEmpty);
      expect(
        rows.every((Map<String, dynamic> row) => row['id'] != null),
        isTrue,
      );
    });
  });

  group('Laravel catalog payload mapping', () {
    final Map<String, dynamic> productPayload = <String, dynamic>{
      'id': 42,
      'name': 'Handwoven Basket',
      'slug': 'handwoven-basket',
      'min_price': '250.00',
      'rating': 4.5,
      'reviews': 6,
      'sold': 12,
      'stock': 8,
      'primary_image': <String, dynamic>{'url': '/storage/products/basket.jpg'},
      'category': <String, dynamic>{'name': 'Home Decor', 'slug': 'home-decor'},
      'seller': <String, dynamic>{'business_name': 'Weave House'},
      'variants': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 63,
          'price': '250.00',
          'stock': 8,
          'description': 'Natural, medium',
          'option_values': <Map<String, dynamic>>[
            <String, dynamic>{'value': 'Natural'},
            <String, dynamic>{'value': 'Medium'},
          ],
        },
      ],
    };

    test('maps nested Laravel fields into home and product cards', () {
      final BuyerHomeProduct homeProduct = BuyerHomeProduct.fromApi(
        productPayload,
      );
      final BuyerProduct? product = BuyerProduct.fromApi(productPayload);

      expect(homeProduct.id, 42);
      expect(homeProduct.price, 250);
      expect(homeProduct.sellerName, 'Weave House');
      expect(homeProduct.category, 'Home Decor');
      expect(
        homeProduct.imageUrl,
        'https://likhae.online/storage/products/basket.jpg',
      );
      expect(product?.price, 250);
      expect(product?.sellerName, 'Weave House');
      expect(product?.category, 'Home Decor');
    });

    test('maps Laravel variants into selectable product detail options', () {
      final ProductDetailData detail = ProductDetailData.fromApi(
        <String, dynamic>{
          ...productPayload,
          'description': 'Handcrafted in the Philippines.',
          'images': <Map<String, dynamic>>[
            <String, dynamic>{
              'url': '/storage/products/basket.jpg',
              'is_primary': true,
            },
          ],
        },
      );

      expect(detail.id, 42);
      expect(detail.price, 250);
      expect(detail.sellerName, 'Weave House');
      expect(detail.category, 'Home Decor');
      expect(detail.variations, hasLength(1));
      expect(detail.variations.single.id, 63);
      expect(detail.variations.single.value, 'Natural, medium');
      expect(detail.variations.single.stock, 8);
      expect(detail.variations.single.price, 250);
    });
  });
}
