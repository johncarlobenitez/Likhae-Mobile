import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';

abstract interface class SmartMessagingClient {
  Future<Map<String, dynamic>> bootstrap({
    required String workspace,
    required String conversationId,
    int? productId,
    int? variantId,
  });

  Future<Map<String, dynamic>> answer({
    required String workspace,
    required String conversationId,
    String? questionKey,
    String? questionText,
    int? productId,
    int? variantId,
  });

  Future<Map<String, dynamic>> feedback({
    required String workspace,
    required String conversationId,
    required String feedback,
  });

  Future<Map<String, dynamic>> requestHuman({
    required String workspace,
    required String conversationId,
    String? concern,
    int? productId,
    int? variantId,
  });
}

class SmartMessagingService implements SmartMessagingClient {
  const SmartMessagingService();

  String _role(String workspace) => workspace == 'rider' ? 'rider' : 'buyer';

  String _conversationUrl(String workspace, String conversationId) {
    final String role = _role(workspace);
    final String id = Uri.encodeComponent(conversationId);
    return '$role/messages/$id/smart-help';
  }

  @override
  Future<Map<String, dynamic>> bootstrap({
    required String workspace,
    required String conversationId,
    int? productId,
    int? variantId,
  }) async {
    _requireOnline();
    final Map<String, dynamic> queryParameters = <String, dynamic>{};
    if (productId != null) queryParameters['product_id'] = productId;
    if (variantId != null) queryParameters['variant_id'] = variantId;
    try {
      final Response<dynamic> response = await ApiClient.get(
        AppConfig.resolveApiUrl(_conversationUrl(workspace, conversationId)),
        queryParameters: queryParameters,
        refresh: true,
      );
      return _payload(response);
    } on DioException catch (error) {
      throw Exception(ApiClient.formatError(error));
    }
  }

  @override
  Future<Map<String, dynamic>> answer({
    required String workspace,
    required String conversationId,
    String? questionKey,
    String? questionText,
    int? productId,
    int? variantId,
  }) {
    final String? key = questionKey?.trim();
    final String? text = questionText?.trim();
    if ((key == null || key.isEmpty) && (text == null || text.isEmpty)) {
      throw const FormatException('Choose a suggested question or enter one.');
    }
    final Map<String, dynamic> data = <String, dynamic>{};
    if (key?.isNotEmpty == true) data['question_key'] = key;
    if (text?.isNotEmpty == true) data['question_text'] = text;
    if (productId != null) data['product_id'] = productId;
    if (variantId != null) data['variant_id'] = variantId;
    return _send(workspace, conversationId, 'answer', data);
  }

  @override
  Future<Map<String, dynamic>> feedback({
    required String workspace,
    required String conversationId,
    required String feedback,
  }) => _send(workspace, conversationId, 'feedback', <String, dynamic>{
    'feedback': feedback,
  });

  @override
  Future<Map<String, dynamic>> requestHuman({
    required String workspace,
    required String conversationId,
    String? concern,
    int? productId,
    int? variantId,
  }) {
    final Map<String, dynamic> data = <String, dynamic>{};
    final String? cleanConcern = concern?.trim();
    if (cleanConcern?.isNotEmpty == true) data['concern'] = cleanConcern;
    if (productId != null) data['product_id'] = productId;
    if (variantId != null) data['variant_id'] = variantId;
    return _send(workspace, conversationId, 'handoff', data);
  }

  Future<Map<String, dynamic>> _send(
    String workspace,
    String conversationId,
    String action,
    Map<String, dynamic> data,
  ) async {
    _requireOnline();
    try {
      final Response<dynamic> response = await ApiClient.post(
        AppConfig.resolveApiUrl(
          '${_conversationUrl(workspace, conversationId)}/$action',
        ),
        data,
      );
      return _payload(response);
    } on DioException catch (error) {
      throw Exception(ApiClient.formatError(error));
    }
  }

  void _requireOnline() {
    if (!AppConfig.apiEnabled) {
      throw Exception('Smart Help needs an internet connection.');
    }
  }

  Map<String, dynamic> _payload(Response<dynamic> response) {
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

    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      response.data as Map,
    );
    if (payload['success'] == false) {
      throw Exception(
        payload['message']?.toString() ?? 'Smart Help is unavailable.',
      );
    }
    final dynamic wrappedData = payload['data'];
    return wrappedData is Map
        ? Map<String, dynamic>.from(wrappedData)
        : payload;
  }
}
