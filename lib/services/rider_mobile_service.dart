import 'dart:async';

import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../features/rider/dashboard/dashboard_screen.dart';
import '../features/rider/deliveries/rider_delivery_models.dart';
import '../features/rider/earnings/rider_earnings_screen.dart';
import '../features/rider/history/rider_history_screen.dart';
import '../features/rider/messages/rider_messages_screen.dart';
import '../features/buyer/notifications/notifications_screen.dart';
import '../features/rider/pickups/rider_pickups_screen.dart';
import '../features/rider/profile/rider_profile_screen.dart';

class RiderDashboardSnapshot {
  final List<RiderDashboardStatData> stats;
  final List<RiderDashboardParcelData> recentParcels;

  const RiderDashboardSnapshot({
    required this.stats,
    required this.recentParcels,
  });
}

class RiderAssignmentsSnapshot {
  final List<RiderDeliveryData> deliveries;
  final RiderDeliveryStatsData stats;

  const RiderAssignmentsSnapshot({
    required this.deliveries,
    required this.stats,
  });
}

class RiderPickupsSnapshot {
  final List<RiderPickupData> pickups;
  final RiderPickupStatsData stats;

  const RiderPickupsSnapshot({required this.pickups, required this.stats});
}

class RiderEarningsSnapshot {
  final List<RiderEarningRowData> rows;
  final String notice;

  const RiderEarningsSnapshot({required this.rows, required this.notice});
}

class RiderMobileService {
  RiderMobileService._();

  static Future<Map<String, dynamic>> _getPayload(
    String endpoint, {
    int page = 1,
  }) async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl(endpoint),
      queryParameters: <String, dynamic>{'page': page, 'per_page': 100},
    );
    return _requirePayload(response);
  }

  static Future<List<dynamic>> _getRows(String endpoint) async {
    final Map<String, dynamic> payload = await _getPayload(endpoint);
    return _getAllRows(endpoint, payload);
  }

  static Future<List<dynamic>> _getAllRows(
    String endpoint,
    Map<String, dynamic> firstPage,
  ) async {
    final List<dynamic> rows = List<dynamic>.from(_rowsFromPayload(firstPage));
    final dynamic meta = firstPage['meta'];
    final int lastPage = meta is Map
        ? int.tryParse((meta['last_page'] ?? 1).toString()) ?? 1
        : 1;
    for (int page = 2; page <= lastPage; page++) {
      rows.addAll(_rowsFromPayload(await _getPayload(endpoint, page: page)));
    }
    return rows;
  }

  static Map<String, dynamic> _requirePayload(Response<dynamic> response) {
    final int statusCode = response.statusCode ?? 500;
    if (statusCode < 200 || statusCode >= 300) {
      final dynamic body = response.data;
      final String message = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Rider API request failed (HTTP $statusCode).';
      throw Exception(message);
    }
    if (response.data is! Map) {
      throw const FormatException('Invalid response from the rider API.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Map<String, dynamic> _map(dynamic value, String description) {
    if (value is! Map) {
      throw FormatException('Invalid $description in rider API response.');
    }
    return Map<String, dynamic>.from(value);
  }

  static List<Map<String, dynamic>> _maps(dynamic value, String description) {
    if (value is! List) {
      throw FormatException('Invalid $description in rider API response.');
    }
    return value
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Future<RiderDashboardSnapshot> fetchDashboard() async {
    final Map<String, dynamic> data = _map(
      (await _getPayload('rider/dashboard'))['data'],
      'dashboard',
    );
    return RiderDashboardSnapshot(
      stats: _maps(
        data['stats'] ?? <dynamic>[],
        'dashboard stats',
      ).map(RiderDashboardStatData.fromApi).toList(growable: false),
      recentParcels:
          _maps(data['recent_parcels'] ?? <dynamic>[], 'recent parcels')
              .map(_withResolvedImage)
              .map(RiderDashboardParcelData.fromApi)
              .toList(growable: false),
    );
  }

  static Future<RiderAssignmentsSnapshot> fetchAssignments() async {
    final Map<String, dynamic> payload = await _getPayload('rider/assignments');
    final List<dynamic> rawRows = await _getAllRows(
      'rider/assignments',
      payload,
    );
    final Map<String, dynamic> data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;
    return RiderAssignmentsSnapshot(
      deliveries: rawRows
          .whereType<Map>()
          .map((Map row) => Map<String, dynamic>.from(row))
          .map(_withResolvedImage)
          .map(RiderDeliveryData.fromApi)
          .toList(growable: false),
      stats: RiderDeliveryStatsData.fromApi(
        data['stats'] is Map
            ? Map<String, dynamic>.from(data['stats'] as Map)
            : const <String, dynamic>{},
      ),
    );
  }

  static Future<RiderPickupsSnapshot> fetchPickups() async {
    final Map<String, dynamic> payload = await _getPayload('rider/pickups');
    final List<dynamic> rawRows = await _getAllRows('rider/pickups', payload);
    final Map<String, dynamic> data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;
    return RiderPickupsSnapshot(
      pickups: rawRows
          .whereType<Map>()
          .map((Map row) => Map<String, dynamic>.from(row))
          .map(_withResolvedImage)
          .map(RiderPickupData.fromApi)
          .toList(growable: false),
      stats: data['stats'] is Map
          ? RiderPickupStatsData.fromApi(
              Map<String, dynamic>.from(data['stats'] as Map),
            )
          : const RiderPickupStatsData(ready: 0, accepted: 0, pickedUp: 0),
    );
  }

  static Future<List<RiderHistoryData>> fetchHistory() async {
    return (await _getRows('rider/history'))
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .map(_withResolvedImage)
        .map(RiderHistoryData.fromApi)
        .toList(growable: false);
  }

  static Future<RiderEarningsSnapshot> fetchEarnings() async {
    final Map<String, dynamic> payload = await _getPayload('rider/earnings');
    final dynamic rawData = payload['data'];
    final Map<String, dynamic> data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : payload;
    final List<dynamic> rows = data['records'] is List
        ? data['records'] as List<dynamic>
        : _rowsFromPayload(payload);
    return RiderEarningsSnapshot(
      rows: rows
          .whereType<Map>()
          .map((Map row) => Map<String, dynamic>.from(row))
          .map(RiderEarningRowData.fromApi)
          .toList(growable: false),
      notice: (data['notice'] ?? '').toString(),
    );
  }

  static Future<RiderProfileData> fetchProfile() async {
    final Map<String, dynamic> payload = await _getPayload('rider/profile');
    final dynamic rawData = payload['data'] ?? payload['user'] ?? payload;
    return RiderProfileData.fromApi(_map(rawData, 'profile'));
  }

  static Future<List<BuyerNotificationData>> fetchNotifications() async {
    return (await _getRows('rider/notifications'))
        .whereType<Map>()
        .map((Map item) {
          final Map<String, dynamic> row = Map<String, dynamic>.from(item);
          final DateTime? createdAt = DateTime.tryParse(
            (row['created_at'] ?? '').toString(),
          );
          return BuyerNotificationData(
            id: (row['id'] ?? '').toString(),
            type: BuyerNotificationData.resolveType(row['type']?.toString()),
            title: (row['title'] ?? '').toString(),
            message: (row['message'] ?? '').toString(),
            time: createdAt == null ? '' : _relativeTime(createdAt),
            unread: row['read_at'] == null,
            createdAt: createdAt,
            actionUrl: row['action_url']?.toString(),
          );
        })
        .toList(growable: false);
  }

  static Future<void> markAllNotificationsRead() async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('rider/notifications/read-all'),
      <String, dynamic>{},
    );
    _requirePayload(response);
  }

  static String _relativeTime(DateTime value) {
    final Duration age = DateTime.now().difference(value);
    if (age.inMinutes < 1) return 'Just now';
    if (age.inHours < 1) return '${age.inMinutes} minutes ago';
    if (age.inDays < 1) return '${age.inHours} hours ago';
    if (age.inDays < 7) return '${age.inDays} days ago';
    return '${value.month}/${value.day}/${value.year}';
  }

  static Future<List<RiderConversationData>> fetchConversations() async {
    return (await _getRows('rider/messages'))
        .whereType<Map>()
        .map((Map row) {
          final Map<String, dynamic> item = Map<String, dynamic>.from(row);
          return RiderConversationData(
            id: (item['id'] ?? item['conversation_id'] ?? '').toString(),
            buyerId: (item['buyer_id'] ?? '').toString(),
            buyerName: (item['buyer_name'] ?? 'Buyer').toString(),
            orderId: item['order_id']?.toString(),
            trackingCode: item['tracking_code']?.toString(),
            lastMessage: (item['last_message'] ?? '').toString(),
            lastMessageAt: DateTime.tryParse(
              (item['last_message_at'] ?? '').toString(),
            ),
            unreadCount:
                int.tryParse((item['unread_count'] ?? 0).toString()) ?? 0,
          );
        })
        .where((RiderConversationData item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<RiderMessageData>> fetchMessages(
    RiderConversationData conversation,
  ) async {
    final String id = conversation.id.trim();
    if (id.isEmpty) {
      throw const FormatException('Conversation identifier is missing.');
    }
    return (await _getRows('rider/messages/${Uri.encodeComponent(id)}'))
        .whereType<Map>()
        .map((Map row) {
          final Map<String, dynamic> item = Map<String, dynamic>.from(row);
          return RiderMessageData(
            id: (item['id'] ?? '').toString(),
            conversationId: (item['conversation_id'] ?? conversation.id)
                .toString(),
            body: (item['body'] ?? '').toString(),
            sentAt:
                DateTime.tryParse((item['sent_at'] ?? '').toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0),
            fromRider: item['from_rider'] == true,
          );
        })
        .toList(growable: false);
  }

  static Stream<RiderMessageData> watchMessages(
    RiderConversationData conversation,
  ) async* {
    final Set<String> knownIds = (await fetchMessages(
      conversation,
    )).map((RiderMessageData message) => message.id).toSet();
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 5));
      for (final RiderMessageData message in await fetchMessages(
        conversation,
      )) {
        if (knownIds.add(message.id)) {
          yield message;
        }
      }
    }
  }

  static Future<RiderMessageData> sendMessage(
    RiderConversationData conversation,
    String body,
  ) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('rider/messages'),
      <String, dynamic>{
        'conversation_id': conversation.id,
        'recipient_id': int.tryParse(conversation.buyerId),
        'body': body,
      },
    );
    final dynamic data = _requirePayload(response)['data'];
    final Map<String, dynamic> row = _map(data, 'sent message');
    return RiderMessageData(
      id: (row['id'] ?? '').toString(),
      conversationId: (row['conversation_id'] ?? conversation.id).toString(),
      body: (row['body'] ?? body).toString(),
      sentAt:
          DateTime.tryParse((row['sent_at'] ?? '').toString()) ??
          DateTime.now(),
      fromRider: row['from_rider'] == true,
    );
  }

  static Future<void> transitionDelivery(
    RiderDeliveryTransitionRequest request,
  ) async {
    if (!request.isValid) {
      throw const FormatException('The delivery update is incomplete.');
    }
    final String endpoint =
        'rider/assignments/${request.delivery.id.toString()}';
    final String status = request.status.trim().toLowerCase();
    final String action = switch (status) {
      'accepted' => 'accept',
      'out_for_delivery' || 'in_transit' => 'start',
      'delivered' => 'delivery_success',
      'failed' || 'delivery_failed' => 'delivery_failed',
      'rejected' => 'reject',
      _ => throw FormatException('Unsupported delivery status: $status.'),
    };
    final Map<String, dynamic> fields = <String, dynamic>{'action': action};
    if (request.note != null && request.note!.trim().isNotEmpty) {
      fields['failure_reason'] = request.note!.trim();
      fields['reason'] = request.note!.trim();
    }
    if (request.receiverName != null &&
        request.receiverName!.trim().isNotEmpty) {
      fields['receiver_name'] = request.receiverName!.trim();
    }
    if (action == 'delivery_failed') {
      fields['attempt_status'] = 'FAILED';
    }
    final String? proofPath = request.proofPath;
    if (proofPath == null || proofPath.trim().isEmpty) {
      final Response<dynamic> response = await ApiClient.patch(
        AppConfig.resolveApiUrl(endpoint),
        fields,
      );
      _requirePayload(response);
      return;
    }

    final FormData formData = FormData.fromMap(<String, dynamic>{
      ...fields,
      '_method': 'PATCH',
      'proof_file': await MultipartFile.fromFile(proofPath),
    });
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(endpoint),
      formData,
    );
    _requirePayload(response);
  }

  static Future<void> updateLiveLocation({
    required int assignmentId,
    required double latitude,
    required double longitude,
  }) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(
        'rider/assignments/$assignmentId/location',
      ),
      <String, dynamic>{'latitude': latitude, 'longitude': longitude},
    );
    _requirePayload(response);
  }

  static Future<void> transitionPickup(
    RiderPickupTransitionRequest request,
  ) async {
    final RiderPickupData pickup = request.pickup;
    final String endpoint = 'rider/assignments/${pickup.id.toString()}';
    var currentStatus = pickup.status.trim().toUpperCase();

    Future<void> sendAction(
      String action, [
      Map<String, dynamic>? fields,
    ]) async {
      final Response<dynamic> response = await ApiClient.patch(
        AppConfig.resolveApiUrl(endpoint),
        <String, dynamic>{'action': action, ...?fields},
      );
      _requirePayload(response);
    }

    if (currentStatus == 'ASSIGNED') {
      await sendAction('accept');
      currentStatus = 'ACCEPTED';
    }
    if (currentStatus == 'ACCEPTED') {
      await sendAction('start');
      currentStatus = 'IN_PROGRESS';
    }

    if (request.status.trim().toLowerCase() != 'picked_up' ||
        currentStatus != 'IN_PROGRESS') {
      throw FormatException(
        'Pickup cannot transition from $currentStatus to ${request.status}.',
      );
    }
    await sendAction('pickup_complete', <String, dynamic>{
      'scanned_code': pickup.trackingCode,
      'scan_method': 'MANUAL',
    });
  }

  static Future<bool> verifyPickup(
    RiderPickupData pickup,
    String trackingCode,
  ) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('rider/pickups/${pickup.id.toString()}/verify'),
      <String, dynamic>{'tracking_code': trackingCode.trim()},
    );
    final Map<String, dynamic> payload = _requirePayload(response);
    final dynamic data = payload['data'];
    return data is Map && data['verified'] == true;
  }

  static List<dynamic> _rowsFromPayload(Map<String, dynamic> payload) {
    final dynamic data = payload['data'];
    if (data is List) {
      return data;
    }
    if (data is Map) {
      for (final String key in <String>[
        'items',
        'assignments',
        'pickups',
        'rows',
        'records',
      ]) {
        if (data[key] is List) {
          return data[key] as List<dynamic>;
        }
      }
    }
    for (final String key in <String>[
      'items',
      'assignments',
      'pickups',
      'rows',
      'records',
    ]) {
      if (payload[key] is List) {
        return payload[key] as List<dynamic>;
      }
    }
    throw const FormatException('Invalid list response from the rider API.');
  }

  static Map<String, dynamic> _withResolvedImage(Map<String, dynamic> row) {
    final dynamic image = row['image_url'] ?? row['image'];
    if (image == null) {
      return row;
    }
    return <String, dynamic>{
      ...row,
      'image_url': AppConfig.resolveMediaUrl(image.toString()),
    };
  }
}
