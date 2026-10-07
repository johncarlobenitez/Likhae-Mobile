import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

class ApiClient {
  ApiClient._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 25),
      headers: <String, String>{
        'Accept': 'application/json',
      },
      validateStatus: (int? status) => status != null && status < 600,
    ),
  );

  static Response<dynamic> _offlineResponse(
    String path, {
    dynamic data,
    int statusCode = 200,
  }) {
    return Response<dynamic>(
      data: data ?? <String, dynamic>{},
      statusCode: statusCode,
      requestOptions: RequestOptions(path: path),
      headers: Headers.fromMap(<String, List<String>>{
        'content-type': <String>['application/json'],
      }),
    );
  }

  static Future<void> initialize() async {
    if (!AppConfig.apiEnabled) {
      return;
    }

    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          final String? token = await TokenStorage.readToken();
          if (token != null && token.trim().isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${token.trim()}';
          }
          options.headers['Accept'] = 'application/json';
          handler.next(options);
        },
        onResponse: (Response<dynamic> response, ResponseInterceptorHandler handler) {
          handler.next(response);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (error.response?.statusCode == 401) {
            await TokenStorage.clearToken();
          }
          handler.next(error);
        },
      ),
    );
  }

  static Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (!AppConfig.apiEnabled) {
      return _offlineResponse(path, data: <String, dynamic>{});
    }

    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  static Future<Response<dynamic>> post(
    String path,
    dynamic data, {
    Options? options,
  }) async {
    if (!AppConfig.apiEnabled) {
      return _offlineResponse(path, data: <String, dynamic>{});
    }

    return _dio.post(
      path,
      data: data,
      options: options,
    );
  }

  static Future<Response<dynamic>> patch(
    String path,
    dynamic data, {
    Options? options,
  }) async {
    if (!AppConfig.apiEnabled) {
      return _offlineResponse(path, data: <String, dynamic>{});
    }

    return _dio.patch(
      path,
      data: data,
      options: options,
    );
  }

  static Future<Response<dynamic>> delete(
    String path,
    dynamic data, {
    Options? options,
  }) async {
    if (!AppConfig.apiEnabled) {
      return _offlineResponse(path, data: <String, dynamic>{});
    }

    return _dio.delete(
      path,
      data: data,
      options: options,
    );
  }

  static String formatError(Object error) {
    if (error is DioException) {
      final Response<dynamic>? response = error.response;
      final dynamic payload = response?.data;

      if (payload is Map<String, dynamic>) {
        final dynamic message = payload['message'];
        final dynamic errors = payload['errors'];

        if (errors is Map && errors.isNotEmpty) {
          final List<String> validationErrors = <String>[];
          for (final value in errors.values) {
            if (value is Iterable) {
              validationErrors.addAll(value.map((dynamic item) => item.toString()));
            } else if (value != null) {
              validationErrors.add(value.toString());
            }
          }
          if (validationErrors.isNotEmpty) {
            return validationErrors.join('\n');
          }
        }

        if (message != null && message.toString().isNotEmpty) {
          return message.toString();
        }
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'The request timed out. Please try again.';
      }

      if (error.type == DioExceptionType.connectionError ||
          error.error is SocketException) {
        return 'No internet connection. Please check your network.';
      }

      if (response != null) {
        final int? statusCode = response.statusCode;
        if (statusCode == 401) {
          return 'Your session has expired. Please sign in again.';
        }
        if (statusCode == 403) {
          return 'You are not allowed to perform this action.';
        }
        if (statusCode == 404) {
          return 'The requested resource was not found.';
        }
        if (statusCode == 422) {
          return 'The submitted data is invalid.';
        }
        if (statusCode == 500) {
          return 'The server is temporarily unavailable.';
        }
      }

      return error.message ?? 'Something went wrong.';
    }

    return error.toString();
  }
}
