import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';

class BuyerNavigationBadges extends ChangeNotifier {
  BuyerNavigationBadges._();

  static final BuyerNavigationBadges instance = BuyerNavigationBadges._();

  int cartCount = 0;
  int orderCount = 0;
  int messageCount = 0;
  int notificationCount = 0;
  DateTime? _lastFetch;
  Future<void>? _pending;

  Future<void> refresh({bool force = false}) {
    if (!AppConfig.apiEnabled) return Future<void>.value();
    final Future<void>? pending = _pending;
    if (pending != null) return pending;
    final DateTime now = DateTime.now();
    if (!force && _lastFetch != null && now.difference(_lastFetch!) < const Duration(seconds: 30)) {
      return Future<void>.value();
    }
    final Future<void> request = _refreshCounts();
    _pending = request;
    return request.whenComplete(() {
      _lastFetch = DateTime.now();
      _pending = null;
    });
  }

  Future<void> _refreshCounts() async {
    Future<int?> nullableCount(Future<int> future) =>
        future.then<int?>((int value) => value, onError: (Object _) => null);
    final List<int?> counts = await Future.wait<int?>(<Future<int?>>[
      nullableCount(_cartCount()),
      nullableCount(_ordersCount()),
      nullableCount(_unreadMessages()),
      nullableCount(_unreadNotifications()),
    ]);
    bool changed = false;
    if (counts[0] != null && counts[0] != cartCount) { cartCount = counts[0]!; changed = true; }
    if (counts[1] != null && counts[1] != orderCount) { orderCount = counts[1]!; changed = true; }
    if (counts[2] != null && counts[2] != messageCount) { messageCount = counts[2]!; changed = true; }
    if (counts[3] != null && counts[3] != notificationCount) { notificationCount = counts[3]!; changed = true; }
    if (changed) notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _fetchRows(String endpoint, {int page = 1}) async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl(endpoint),
      queryParameters: <String, dynamic>{'page': page, 'per_page': 50},
      refresh: true,
    );
    final int status = response.statusCode ?? 500;
    if (status < 200 || status >= 300 || response.data is! Map) {
      throw Exception('Unable to refresh buyer navigation counts.');
    }
    final Map<String, dynamic> payload = Map<String, dynamic>.from(response.data as Map);
    final dynamic data = payload['data'];
    if (data is! List) return <Map<String, dynamic>>[];
    return data.whereType<Map>().map((Map row) => Map<String, dynamic>.from(row)).toList(growable: false);
  }

  Future<int> _cartCount() async {
    final List<Map<String, dynamic>> rows = await _fetchRows('buyer/cart');
    return rows.fold<int>(0, (int total, Map<String, dynamic> row) =>
        total + (int.tryParse((row['quantity'] ?? 1).toString()) ?? 1));
  }

  Future<int> _ordersCount() async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('buyer/orders'),
      queryParameters: const <String, dynamic>{'page': 1, 'per_page': 1},
      refresh: true,
    );
    if ((response.statusCode ?? 500) >= 400 || response.data is! Map) {
      throw Exception('Unable to refresh order count.');
    }
    final Map<String, dynamic> payload = Map<String, dynamic>.from(response.data as Map);
    final dynamic meta = payload['meta'];
    if (meta is Map && meta['total'] != null) return int.tryParse(meta['total'].toString()) ?? 0;
    final dynamic data = payload['data'];
    return data is List ? data.length : 0;
  }

  Future<int> _unreadMessages() async {
    final List<Map<String, dynamic>> rows = await _fetchRows('buyer/messages');
    return rows.fold<int>(0, (int total, Map<String, dynamic> row) =>
        total + (int.tryParse((row['unread'] ?? 0).toString()) ?? 0));
  }

  Future<int> _unreadNotifications() async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('buyer/notifications'),
      queryParameters: const <String, dynamic>{'page': 1, 'per_page': 1},
      refresh: true,
    );
    if ((response.statusCode ?? 500) >= 400 || response.data is! Map) {
      throw Exception('Unable to refresh notification count.');
    }
    final Map<String, dynamic> payload = Map<String, dynamic>.from(response.data as Map);
    return int.tryParse((payload['unread_count'] ?? 0).toString()) ?? 0;
  }
}
