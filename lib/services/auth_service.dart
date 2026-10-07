import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../core/storage/token_storage.dart';
import '../models/auth_user_model.dart';
import '../features/auth/register_screen.dart';

class AuthService {
  static Future<Map<String, dynamic>> register(RegisterFormData data) async {
    if (!AppConfig.apiEnabled) {
      throw const FormatException(
        'Enable the Laravel API with --dart-define=API_ENABLED=true before registering.',
      );
    }

    final Map<String, dynamic> fields = <String, dynamic>{
      'account_type': data.accountType == MobileAccountType.rider ? 'rider' : 'buyer',
      'first_name': data.firstName,
      'middle_initial': data.middleInitial,
      'last_name': data.lastName,
      'sex': data.sex.toLowerCase(),
      'birthday': _formatDate(data.birthday),
      'age': data.age.toString(),
      'email': data.email,
      'contact_number': data.contactNumber,
      'region': data.region.name,
      'region_code': data.region.code,
      'province': data.province.name,
      'province_code': data.province.code,
      'municipality': data.municipality.name,
      'municipality_code': data.municipality.code,
      'barangay': data.barangay.name,
      'barangay_code': data.barangay.code,
      'street': data.street,
      'house_number': data.houseNumber,
      'postal_code': data.postalCode,
      'landmark': data.landmark,
      'password': data.password,
      'password_confirmation': data.password,
      'terms': '1',
    };

    if (data.vehicleType != null) fields['vehicle_type'] = data.vehicleType;
    if (data.plateNumber != null) fields['plate_number'] = data.plateNumber;
    Future<void> addFile(String field, RegistrationDocument? document) async {
      if (document?.path == null || document!.path!.isEmpty) return;
      fields[field] = await MultipartFile.fromFile(
        document.path!,
        filename: document.name,
      );
    }
    await addFile('valid_id', data.validId);
    await addFile('or_cr', data.vehicleOrCr);
    await addFile('drivers_license', data.driversLicense);

    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('auth/register'),
      FormData.fromMap(fields),
    );
    if ((response.statusCode ?? 500) >= 400) {
      final DioException error = DioException.badResponse(
        statusCode: response.statusCode ?? 500,
        requestOptions: response.requestOptions,
        response: response,
      );
      throw Exception(ApiClient.formatError(error));
    }
    final dynamic payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid registration response from server.');
    }
    return payload;
  }

  static String _formatDate(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

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
