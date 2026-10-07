import '../features/buyer/orders/orders_screen.dart';
import 'buyer_mobile_service.dart';

class OrderService {
  static Future<List<BuyerOrderData>> fetchMyOrders() async {
    return BuyerMobileService.fetchOrders();
  }
}
