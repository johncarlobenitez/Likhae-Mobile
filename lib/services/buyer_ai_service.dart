import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';

class BuyerAiResponse {
  final String reply;
  final List<String> options;

  const BuyerAiResponse({required this.reply, this.options = const <String>[]});
}

class BuyerAiService {
  BuyerAiService._();

  static Future<BuyerAiResponse> lookupOrder(String orderReference) =>
      chat(message: orderReference, page: 'orders');

  static Future<BuyerAiResponse> chat({
    required String message,
    String page = 'buyer',
    String workspace = 'buyer',
  }) async {
    final String normalizedWorkspace = workspace == 'rider' ? 'rider' : 'buyer';
    if (!AppConfig.apiEnabled) {
      return const BuyerAiResponse(
        reply:
            'The workspace assistant is ready. Enable the mobile API to connect it to your LIKHAE account.',
      );
    }

    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('$normalizedWorkspace/ai/chat'),
      <String, dynamic>{'message': message.trim(), 'page': page},
    );

    final int statusCode = response.statusCode ?? 500;
    if (statusCode < 200 || statusCode >= 300) {
      throw Exception(_errorMessage(response, statusCode));
    }

    final dynamic rawPayload = response.data;
    if (rawPayload is! Map) {
      throw const FormatException('The workspace assistant returned an invalid response.');
    }

    final Map<String, dynamic> payload = Map<String, dynamic>.from(rawPayload);
    final String reply = payload['reply']?.toString().trim() ?? '';
    if (reply.isEmpty) {
      throw const FormatException('The workspace assistant returned an empty response.');
    }

    final dynamic rawOptions = payload['options'];
    final List<String> options = rawOptions is Iterable
        ? rawOptions
            .map((dynamic option) => option.toString().trim())
            .where((String option) => option.isNotEmpty)
            .take(6)
            .toList(growable: false)
        : const <String>[];

    return BuyerAiResponse(reply: reply, options: options);
  }

  static String _errorMessage(Response<dynamic> response, int statusCode) {
    final dynamic rawPayload = response.data;
    if (rawPayload is Map && rawPayload['message'] != null) {
      return rawPayload['message'].toString();
    }

    return 'Assistant request failed (HTTP $statusCode).';
  }
}
