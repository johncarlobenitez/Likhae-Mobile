import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import 'buyer_mobile_service.dart';

class BuyerAiResponse {
  final String reply;
  final List<String> options;

  const BuyerAiResponse({required this.reply, this.options = const <String>[]});
}

class BuyerAiService {
  BuyerAiService._();

  static Future<BuyerAiResponse> lookupOrder(String orderReference) async {
    if (!AppConfig.apiEnabled) {
      return const BuyerAiResponse(
        reply: 'Order lookup needs the mobile API connection enabled.',
      );
    }

    final String requested = orderReference.trim().toUpperCase();
    final orders = await BuyerMobileService.fetchOrders();
    for (final order in orders) {
      final String reference = (order.orderNumber ?? '').trim().toUpperCase();
      if (reference != requested) continue;

      final String status = order.statusLabel.trim().isNotEmpty
          ? order.statusLabel.trim()
          : (order.backendStatus ?? order.status).trim();
      final String displayReference =
          order.orderNumber?.trim().isNotEmpty == true
          ? order.orderNumber!.trim()
          : orderReference.trim();
      final List<String> details = <String>[
        'Order $displayReference is currently $status.',
      ];
      final String? tracking = order.tracking?.trim();
      if (tracking != null && tracking.isNotEmpty) {
        details.add('Tracking number: $tracking.');
      } else {
        details.add('A tracking number is not available yet.');
      }
      return BuyerAiResponse(reply: details.join('\n'));
    }

    return BuyerAiResponse(
      reply:
          'I couldn’t find order $orderReference in your account. Refresh your orders and try selecting it again.',
    );
  }

  static Future<BuyerAiResponse> chat({
    required String message,
    String page = 'buyer',
  }) async {
    if (!AppConfig.apiEnabled) {
      return const BuyerAiResponse(
        reply:
            'The Buyer AI Assistant is ready. Enable the mobile API to connect it to your LIKHAE account.',
      );
    }

    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('buyer/ai/chat'),
      <String, dynamic>{'message': message.trim(), 'page': page},
    );

    final int statusCode = response.statusCode ?? 500;
    if (statusCode < 200 || statusCode >= 300) {
      throw Exception(_errorMessage(response, statusCode));
    }

    final dynamic rawPayload = response.data;
    if (rawPayload is! Map) {
      throw const FormatException('The Buyer AI returned an invalid response.');
    }

    final Map<String, dynamic> payload = Map<String, dynamic>.from(rawPayload);
    final String reply = payload['reply']?.toString().trim() ?? '';
    if (reply.isEmpty) {
      throw const FormatException('The Buyer AI returned an empty response.');
    }

    final dynamic rawOptions = payload['options'];
    final List<String> options = rawOptions is Iterable
        ? rawOptions
            .map((dynamic option) => option.toString().trim())
            .where((String option) => option.isNotEmpty)
            .take(4)
            .toList(growable: false)
        : const <String>[];

    return BuyerAiResponse(reply: reply, options: options);
  }

  static String _errorMessage(Response<dynamic> response, int statusCode) {
    final dynamic rawPayload = response.data;
    if (rawPayload is Map && rawPayload['message'] != null) {
      return rawPayload['message'].toString();
    }

    return 'Buyer AI request failed (HTTP $statusCode).';
  }
}
