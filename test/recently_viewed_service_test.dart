import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/products/product_details_screen.dart';
import 'package:likhae/services/recently_viewed_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  ProductDetailData product(int id, {double price = 100}) => ProductDetailData(
    id: id,
    name: 'Product $id',
    slug: 'product-$id',
    price: price,
  );

  test(
    'persists views, moves revisits first, and refreshes product data',
    () async {
      await RecentlyViewedService.record(product(1));
      await RecentlyViewedService.record(product(2));
      await RecentlyViewedService.record(product(1, price: 250));
      final history = await RecentlyViewedService.read();
      expect(history.map((p) => p.id), [1, 2]);
      expect(history.first.price, 250);
      expect(history.first.slug, 'product-1');
      expect(
        await const FlutterSecureStorage().read(key: 'recently_viewed_1'),
        isNotNull,
      );
    },
  );

  test('concurrent views retain the newest fifty and can be cleared', () async {
    await Future.wait([
      for (int id = 1; id <= 55; id++)
        RecentlyViewedService.record(product(id)),
    ]);
    final history = await RecentlyViewedService.read();
    expect(history.length, 50);
    expect(history.first.id, 55);
    expect(history.last.id, 6);
    await RecentlyViewedService.clear();
    expect(await RecentlyViewedService.read(), isEmpty);
  });
}
