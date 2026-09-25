import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/api/api_client.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/services/product_service.dart';

void main() {
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
    test('disables the API layer while layout work is being finished', () async {
      expect(AppConfig.apiEnabled, isFalse);

      final Response<dynamic> response = await ApiClient.get('demo');

      expect(response.statusCode, 200);
      expect(response.data, isEmpty);
    });

    test('returns a shuffled local product list instead of an empty feed', () async {
      final List<dynamic> products = await ProductService.fetchHomeProducts();

      expect(products, isNotEmpty);
      expect(products.length, greaterThanOrEqualTo(4));
    });
  });
}
