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
    if (!AppConfig.apiEnabled) {
      final Map<String, dynamic> dummyUser = <String, dynamic>{
        'id': 1,
        'name': 'Demo Buyer',
        'email': email.isEmpty ? 'buyer@likhae.test' : email,
        'contact_number': '+639000000001',
        'status': 'active',
        'email_verified': true,
        'mobile_roles': <String>['buyer'],
        'roles': <String>['buyer'],
      };

      return <String, dynamic>{
        'token': 'demo-token',
        'user': dummyUser,
        'data': <String, dynamic>{'user': dummyUser},
      };
    }

    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('auth/login'),
      <String, dynamic>{
        'email': email,
        'password': password,
        'device_name': deviceName,
      },
    );

    if ((response.statusCode ?? 500) >= 400) {
      final dynamic responseData = response.data;
      final String message = responseData is Map && responseData['message'] != null
          ? responseData['message'].toString()
          : 'Unable to sign in with these credentials.';
      throw Exception(message);
    }

    final dynamic payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid login response from server.');
    }

    final String? newToken =
      (payload['token'] ?? payload['access_token'])?.toString();
    if (newToken != null && newToken.isNotEmpty) {
      await TokenStorage.writeToken(newToken);
    }

    return payload;
  }

  static Future<AuthUserModel> getCurrentUser() async {
    if (!AppConfig.apiEnabled) {
      return AuthUserModel(
        id: 1,
        name: 'Demo Buyer',
        email: 'buyer@likhae.test',
        contactNumber: '+639000000001',
        status: 'active',
        emailVerified: true,
        roles: const <String>['buyer'],
        mobileRoles: const <String>['buyer'],
      );
    }

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
