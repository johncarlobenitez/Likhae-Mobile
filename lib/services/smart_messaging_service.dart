import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';

class SmartMessagingService {
  SmartMessagingService._();

  static Future<Map<String, dynamic>> answer({
    required String workspace,
    required String conversationId,
    required String question,
  }) => _send(workspace, conversationId, 'answer', <String, dynamic>{
    'question_text': question.trim(),
  });

  static Future<Map<String, dynamic>> feedback({
    required String workspace,
    required String conversationId,
    required String feedback,
  }) => _send(workspace, conversationId, 'feedback', <String, dynamic>{
    'feedback': feedback,
  });

  static Future<Map<String, dynamic>> requestHuman({
    required String workspace,
    required String conversationId,
    String? concern,
  }) => _send(workspace, conversationId, 'handoff', <String, dynamic>{
    if (concern?.trim().isNotEmpty == true) 'concern': concern!.trim(),
  });

  static Future<Map<String, dynamic>> _send(
    String workspace,
    String conversationId,
    String action,
    Map<String, dynamic> data,
  ) async {
    final String role = workspace == 'rider' ? 'rider' : 'buyer';
    try {
      final Response<dynamic> response = await ApiClient.post(
        AppConfig.resolveApiUrl(
          '$role/messages/${Uri.encodeComponent(conversationId)}/smart-help/$action',
        ),
        data,
      );
      if ((response.statusCode ?? 500) < 200 ||
          (response.statusCode ?? 500) >= 300 ||
          response.data is! Map) {
        throw Exception(
          ApiClient.formatError(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
            ),
          ),
        );
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (error) {
      throw Exception(ApiClient.formatError(error));
    }
  }
}
