import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../features/buyer/orders/orders_screen.dart';

class OrderService {
  static Future<List<BuyerOrderData>> fetchMyOrders() async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('orders'),
    );

    final dynamic payload = response.data;
    if (payload is! Map<String, dynamic>) {
      return <BuyerOrderData>[];
    }

    final dynamic rows = payload['data'] ?? payload['orders'] ?? payload['items'];
    if (rows is! List) {
      return <BuyerOrderData>[];
    }

    return rows
        .whereType<Map>()
        .map((Map item) => BuyerOrderData.fromApi(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }
}
