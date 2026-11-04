import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/config/app_config.dart';

/// Shared transport for the additional buyer and rider workflows.
class WorkspaceMobileService {
  static Map<String, dynamic> payload(Response<dynamic> response) {
    if ((response.statusCode ?? 500) >= 500) {
      throw Exception(
        'The service could not confirm this request. Refresh its status before trying again.',
      );
    }
    if ((response.statusCode ?? 500) < 200 ||
        (response.statusCode ?? 500) >= 300 ||
        response.data is! Map ||
        response.data['success'] == false) {
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
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async => payload(
    await ApiClient.get(
      AppConfig.resolveApiUrl(path),
      queryParameters: query,
      refresh: true,
    ),
  );

  static Future<Map<String, dynamic>> send(
    String path,
    dynamic data, {
    String method = 'POST',
  }) async {
    final url = AppConfig.resolveApiUrl(path);
    try {
      return payload(
        await (method == 'PUT'
            ? ApiClient.put(url, data)
            : ApiClient.post(url, data)),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw Exception(
          'We could not confirm whether the request was received. Refresh its status before submitting again.',
        );
      }
      throw Exception(ApiClient.formatError(error));
    }
  }

  static Future<List<Map<String, dynamic>>> rows(String path) async {
    final result = <Map<String, dynamic>>[];
    var page = 1;
    var last = 1;
    do {
      final body = await get(path, query: {'page': page});
      result.addAll(maps(body['data']));
      last = int.tryParse('${body['meta']?['last_page'] ?? 1}') ?? 1;
      page++;
    } while (page <= last);
    return result;
  }

  static List<Map<String, dynamic>> maps(dynamic rows) => rows is List
      ? rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
      : <Map<String, dynamic>>[];

  static Future<({Uint8List bytes, String mime})> file(String path) async {
    final response = await ApiClient.get(
      AppConfig.resolveApiUrl(path),
      options: Options(responseType: ResponseType.bytes),
      refresh: true,
    );
    if ((response.statusCode ?? 500) != 200) {
      throw Exception('This private file could not be loaded.');
    }
    return (
      bytes: Uint8List.fromList(List<int>.from(response.data as List)),
      mime:
          response.headers.value('content-type') ?? 'application/octet-stream',
    );
  }
}
