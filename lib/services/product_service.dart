import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../features/buyer/home/home_screen.dart';

class ProductService {
  static Future<List<BuyerHomeProduct>> fetchHomeProducts() async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('products'),
      queryParameters: <String, dynamic>{
        'per_page': 10,
      },
    );

    final dynamic payload = response.data;
    if (payload is! Map<String, dynamic>) {
      return <BuyerHomeProduct>[];
    }

    final dynamic rows = payload['data'] ?? payload['products'] ?? payload['items'];
    if (rows is! List) {
      return <BuyerHomeProduct>[];
    }

    return rows
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return BuyerHomeProduct.fromApi(Map<String, dynamic>.from(item as Map));
          }
          return BuyerHomeProduct.fromApi(item);
        })
        .where((BuyerHomeProduct product) => product.id != 0)
        .toList(growable: false);
  }
}
