import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../features/buyer/home/home_screen.dart';

class ProductService {
  static List<BuyerHomeProduct> _demoProducts() {
    final List<BuyerHomeProduct> products = <BuyerHomeProduct>[
      const BuyerHomeProduct(
        id: 1,
        name: 'Minimal Ceramic Vase',
        price: 799,
        originalPrice: 999,
        category: 'Home Decor',
        sellerName: 'Mira Studio',
        imageUrl: 'https://images.unsplash.com/photo-1517705008128-361805f42e86?auto=format&fit=crop&w=900&q=80',
        rating: 4.8,
        soldCount: 182,
        stock: 8,
        isFeatured: true,
        isRecommended: true,
      ),
      const BuyerHomeProduct(
        id: 2,
        name: 'Linen Everyday Tote',
        price: 1299,
        originalPrice: 1699,
        category: 'Fashion',
        sellerName: 'Northline Co.',
        imageUrl: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=900&q=80',
        rating: 4.7,
        soldCount: 248,
        stock: 12,
        isFeatured: true,
      ),
      const BuyerHomeProduct(
        id: 3,
        name: 'Wireless Noise Cancelling Headphones',
        price: 5399,
        originalPrice: 6299,
        category: 'Electronics',
        sellerName: 'Echo Labs',
        imageUrl: 'https://images.unsplash.com/photo-1546435770-a3e426bf472b?auto=format&fit=crop&w=900&q=80',
        rating: 4.9,
        soldCount: 96,
        stock: 15,
        isRecommended: true,
      ),
      const BuyerHomeProduct(
        id: 4,
        name: 'Leather Journal Set',
        price: 899,
        originalPrice: 1199,
        category: 'Office',
        sellerName: 'Paper & Pine',
        imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=900&q=80',
        rating: 4.6,
        soldCount: 135,
        stock: 11,
        isFeatured: true,
        isRecommended: true,
      ),
      const BuyerHomeProduct(
        id: 5,
        name: 'Forest Scent Candle Trio',
        price: 699,
        originalPrice: 899,
        category: 'Home',
        sellerName: 'Velvet Ember',
        imageUrl: 'https://images.unsplash.com/photo-1503602642458-232111445657?auto=format&fit=crop&w=900&q=80',
        rating: 4.7,
        soldCount: 204,
        stock: 18,
        isRecommended: true,
      ),
      const BuyerHomeProduct(
        id: 6,
        name: 'City Walk Running Shoes',
        price: 2499,
        originalPrice: 3299,
        category: 'Sports',
        sellerName: 'Stride Daily',
        imageUrl: 'https://images.unsplash.com/photo-1543508282-6319a3e2621f?auto=format&fit=crop&w=900&q=80',
        rating: 4.8,
        soldCount: 312,
        stock: 20,
        isFeatured: true,
      ),
      const BuyerHomeProduct(
        id: 7,
        name: 'Stoneware Dinner Set',
        price: 1899,
        originalPrice: 2399,
        category: 'Kitchen',
        sellerName: 'Gather & Glow',
        imageUrl: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=900&q=80',
        rating: 4.6,
        soldCount: 143,
        stock: 9,
        isRecommended: true,
      ),
      const BuyerHomeProduct(
        id: 8,
        name: 'Soft Knit Throw Blanket',
        price: 1499,
        originalPrice: 1999,
        category: 'Home',
        sellerName: 'Harbor & Hearth',
        imageUrl: 'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=900&q=80',
        rating: 4.9,
        soldCount: 271,
        stock: 14,
        isFeatured: true,
        isRecommended: true,
      ),
    ];

    products.shuffle();
    return products;
  }

  static Future<List<BuyerHomeProduct>> fetchHomeProducts() async {
    if (!AppConfig.apiEnabled) {
      return _demoProducts();
    }

    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('products'),
      queryParameters: <String, dynamic>{
        'per_page': 10,
      },
    );

    final dynamic payload = response.data;
    if (payload is! Map<String, dynamic>) {
      return _demoProducts();
    }

    final dynamic rows = payload['data'] ?? payload['products'] ?? payload['items'];
    if (rows is! List) {
      return _demoProducts();
    }

    final List<BuyerHomeProduct> mappedProducts = rows
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return BuyerHomeProduct.fromApi(Map<String, dynamic>.from(item as Map));
          }
          return BuyerHomeProduct.fromApi(item);
        })
        .where((BuyerHomeProduct product) => product.id != 0)
        .toList(growable: false);

    if (mappedProducts.isEmpty) {
      return _demoProducts();
    }

    final List<BuyerHomeProduct> shuffled = List<BuyerHomeProduct>.from(mappedProducts)..shuffle();
    return shuffled;
  }
}
