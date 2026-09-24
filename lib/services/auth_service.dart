import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../core/storage/token_storage.dart';
import '../models/auth_user_model.dart';

class AuthService {
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('auth/login'),
      <String, dynamic>{
        'email': email,
        'password': password,
        'device_name': deviceName,
      },
    );

    final dynamic payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid login response from server.');
    }

    final String? newToken = payload['token']?.toString();
    if (newToken != null && newToken.isNotEmpty) {
      await TokenStorage.writeToken(newToken);
    }

    return payload;
  }

  static Future<AuthUserModel> getCurrentUser() async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('auth/me'),
    );

    final dynamic payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid auth/me response from server.');
    }

    final dynamic userData = payload['user'] ?? payload['data'] ?? payload;
    if (userData is! Map<String, dynamic>) {
      throw const FormatException('User data not found in auth/me response.');
    }

    return AuthUserModel.fromJson(userData);
  }

  static Future<void> logout() async {
    try {
      await ApiClient.post(
        AppConfig.resolveApiUrl('auth/logout'),
        <String, dynamic>{},
      );
    } catch (_) {
      // Ignore backend logout errors; local token deletion is still required.
    }

    await TokenStorage.clearToken();
  }
}
