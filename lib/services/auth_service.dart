import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../core/storage/token_storage.dart';
import '../models/auth_user_model.dart';
import '../models/platform_policy.dart';
import '../features/auth/register_screen.dart';
import 'wishlist_service.dart';

class GoogleRegistrationRequiredException implements Exception {
  final Map<String, dynamic> profile;

  const GoogleRegistrationRequiredException(this.profile);

  @override
  String toString() => 'Complete your buyer registration to continue.';
}

class AuthSessionExpiredException implements Exception {
  const AuthSessionExpiredException();

  @override
  String toString() => 'Your session has expired. Please sign in again.';
}

class AuthenticatedUserSession {
  final AuthUserModel user;
  final List<PlatformPolicy> pendingPolicies;

  const AuthenticatedUserSession({
    required this.user,
    this.pendingPolicies = const <PlatformPolicy>[],
  });
}

class AuthService {
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    if (!AppConfig.apiEnabled) {
      throw const FormatException(
        'Enable the Laravel API before using Google sign-in.',
      );
    }

    const String callbackScheme = 'likhae';
    final String state = _randomToken(32);
    final String codeVerifier = _randomToken(64);
    final String codeChallenge = base64Url
        .encode(sha256.convert(utf8.encode(codeVerifier)).bytes)
        .replaceAll('=', '');
    final String webBaseUrl = AppConfig.webBaseUrl.replaceFirst(
      RegExp(r'/$'),
      '',
    );
    final Uri authorizationUri = Uri.parse('$webBaseUrl/auth/google/mobile')
        .replace(
          queryParameters: <String, String>{
            'state': state,
            'code_challenge': codeChallenge,
          },
        );

    final String callback = await FlutterWebAuth2.authenticate(
      url: authorizationUri.toString(),
      callbackUrlScheme: callbackScheme,
    );
    final Uri callbackUri = Uri.parse(callback);

    if (callbackUri.scheme != callbackScheme ||
        callbackUri.host != 'auth' ||
        callbackUri.path != '/google-callback' ||
        callbackUri.queryParameters['state'] != state) {
      throw const FormatException(
        'Google sign-in returned an invalid callback.',
      );
    }

    final String? callbackError = callbackUri.queryParameters['error'];
    if (callbackError != null && callbackError.isNotEmpty) {
      throw Exception(_googleCallbackError(callbackError));
    }

    final String code = callbackUri.queryParameters['code']?.trim() ?? '';
    if (code.isEmpty) {
      throw const FormatException(
        'Google sign-in did not return an authorization code.',
      );
    }

    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('auth/google/exchange'),
      <String, dynamic>{
        'code': code,
        'code_verifier': codeVerifier,
        'device_name': 'LIKHAE Flutter',
      },
    );
    final Map<String, dynamic> payload = _jsonMap(response.data);

    if ((response.statusCode ?? 500) == 409 &&
        payload['code'] == 'google_registration_required') {
      final dynamic profile = payload['profile'];
      if (profile is Map) {
        throw GoogleRegistrationRequiredException(
          Map<String, dynamic>.from(profile),
        );
      }
    }

    if ((response.statusCode ?? 500) >= 400) {
      throw Exception(
        payload['message']?.toString() ?? 'Unable to sign in with Google.',
      );
    }

    final String? token = (payload['token'] ?? payload['access_token'])
        ?.toString();
    if (token == null || token.isEmpty) {
      throw const FormatException(
        'Google sign-in response did not include a session token.',
      );
    }
    await TokenStorage.writeToken(token);
    await WishlistService.clearLocalWishlist();
    return payload;
  }

  static String _randomToken(int length) {
    const String alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final Random random = Random.secure();
    return List<String>.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
      growable: false,
    ).join();
  }

  static String _googleCallbackError(String code) => switch (code) {
    'cancelled' || 'access_denied' => 'Google sign-in was cancelled.',
    'google_unavailable' =>
      'Google sign-in is not configured on the server yet.',
    'unverified_email' =>
      'Google must return a verified email address to continue.',
    'inactive_account' =>
      'This LIKHAE account is inactive. Contact support for help.',
    'mobile_access_required' =>
      'This account does not have Buyer, Rider, or Logistics mobile access.',
    _ => 'Google sign-in could not be completed. Please try again.',
  };

  static Map<String, dynamic> _jsonMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Invalid Google sign-in response from server.');
  }

  static Future<void> sendRegistrationEmailVerificationCode(
    String email,
  ) async {
    if (!AppConfig.apiEnabled) {
      throw const FormatException(
        'Enable the Laravel API with --dart-define=API_ENABLED=true before verifying email.',
      );
    }

    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('auth/register/email-verification/send'),
      <String, dynamic>{'email': email.trim()},
    );

    if ((response.statusCode ?? 500) >= 400) {
      final DioException error = DioException.badResponse(
        statusCode: response.statusCode ?? 500,
        requestOptions: response.requestOptions,
        response: response,
      );
      throw Exception(ApiClient.formatError(error));
    }
  }

  static Future<String> verifyRegistrationEmailVerificationCode({
    required String email,
    required String code,
  }) async {
    if (!AppConfig.apiEnabled) {
      throw const FormatException(
        'Enable the Laravel API with --dart-define=API_ENABLED=true before verifying email.',
      );
    }

    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('auth/register/email-verification/verify'),
      <String, dynamic>{'email': email.trim(), 'code': code.trim()},
    );

    if ((response.statusCode ?? 500) >= 400) {
      final DioException error = DioException.badResponse(
        statusCode: response.statusCode ?? 500,
        requestOptions: response.requestOptions,
        response: response,
      );
      throw Exception(ApiClient.formatError(error));
    }

    final String? token = _extractEmailVerificationToken(response.data);

    if (token == null || token.isEmpty) {
      throw const FormatException(
        'The server did not return an email verification token.',
      );
    }

    return token;
  }

  static Future<List<LogisticsCenterOption>> fetchLogisticsCenters() async {
    if (!AppConfig.apiEnabled) {
      throw const FormatException(
        'Enable the Laravel API before loading logistics hubs.',
      );
    }

    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('logistics-centers'),
    );
    if ((response.statusCode ?? 500) >= 400) {
      throw Exception('Unable to load active logistics hubs.');
    }

    dynamic rows = response.data;
    if (rows is Map) rows = rows['data'];
    if (rows is! List) {
      throw const FormatException('Invalid logistics hub response from server.');
    }

    final List<LogisticsCenterOption> centers = <LogisticsCenterOption>[];
    for (final dynamic row in rows) {
      if (row is! Map) continue;
      final int? id = int.tryParse(row['id']?.toString() ?? '');
      final String code = row['code']?.toString().trim() ?? '';
      final String name = row['business_name']?.toString().trim() ?? '';
      if (id == null || name.isEmpty) continue;
      centers.add(LogisticsCenterOption(id: id, code: code, name: name));
    }

    return centers;
  }

  static String? _extractEmailVerificationToken(dynamic payload) {
    if (payload is! Map) {
      return null;
    }

    for (final String key in <String>[
      'verification_token',
      'email_verification_token',
      'token',
    ]) {
      final String value = payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    final dynamic nestedData = payload['data'];
    if (nestedData is Map) {
      return _extractEmailVerificationToken(nestedData);
    }

    return null;
  }

  static Future<void> sendPasswordResetLink(String email) async {
    if (!AppConfig.apiEnabled) {
      throw const FormatException(
        'Enable the Laravel API with --dart-define=API_ENABLED=true before requesting a password reset.',
      );
    }

    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('auth/password/email'),
      <String, dynamic>{'email': email.trim()},
    );

    if ((response.statusCode ?? 500) >= 400) {
      throw DioException.badResponse(
        statusCode: response.statusCode ?? 500,
        requestOptions: response.requestOptions,
        response: response,
      );
    }
  }

  static Future<Map<String, dynamic>> register(RegisterFormData data) async {
    if (!AppConfig.apiEnabled) {
      throw const FormatException(
        'Enable the Laravel API with --dart-define=API_ENABLED=true before registering.',
      );
    }

    final Map<String, dynamic> fields = <String, dynamic>{
      'account_type': data.accountType == MobileAccountType.rider
          ? 'rider'
          : 'buyer',
      'first_name': data.firstName,
      'middle_initial': data.middleInitial,
      'last_name': data.lastName,
      'sex': data.sex.toLowerCase().replaceAll(' ', '_'),
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
      'email_verification_token': data.emailVerificationToken,
    };

    if (data.vehicleType != null) fields['vehicle_type'] = data.vehicleType;
    if (data.plateNumber != null) fields['plate_number'] = data.plateNumber;
    if (data.targetLogisticsCenterId != null) {
      fields['target_logistics_center_id'] = data.targetLogisticsCenterId;
    }
    if (data.driversLicenseNumber != null) {
      fields['drivers_license_number'] = data.driversLicenseNumber;
    }
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
      await TokenStorage.writeToken('demo-token');
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
      final String message =
          responseData is Map && responseData['message'] != null
          ? responseData['message'].toString()
          : 'Unable to sign in with these credentials.';
      throw Exception(message);
    }

    final dynamic payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid login response from server.');
    }

    final String? newToken = (payload['token'] ?? payload['access_token'])
        ?.toString();
    if (newToken == null || newToken.trim().isEmpty) {
      throw const FormatException(
        'Login response did not include a session token.',
      );
    }
    await TokenStorage.writeToken(newToken.trim());
    await WishlistService.clearLocalWishlist();

    return payload;
  }

  static Future<AuthenticatedUserSession> getCurrentSession() async {
    if (!AppConfig.apiEnabled) {
      return AuthenticatedUserSession(
        user: AuthUserModel(
          id: 1,
          name: 'Demo Buyer',
          email: 'buyer@likhae.test',
          contactNumber: '+639000000001',
          status: 'active',
          emailVerified: true,
          roles: const <String>['buyer'],
          mobileRoles: const <String>['buyer'],
        ),
      );
    }

    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('auth/me'),
    );

    final int statusCode = response.statusCode ?? 500;
    if (statusCode == 401) {
      await TokenStorage.clearToken();
      throw const AuthSessionExpiredException();
    }
    if (statusCode < 200 || statusCode >= 300) {
      final dynamic responseData = response.data;
      final String message =
          responseData is Map && responseData['message'] != null
          ? responseData['message'].toString()
          : 'Unable to verify your saved session.';
      throw Exception(message);
    }

    final dynamic payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid auth/me response from server.');
    }

    final dynamic userData = payload['user'] ?? payload['data'] ?? payload;
    if (userData is! Map<String, dynamic>) {
      throw const FormatException('User data not found in auth/me response.');
    }

    return AuthenticatedUserSession(
      user: AuthUserModel.fromJson(userData),
      pendingPolicies: PlatformPolicy.parseList(payload['pending_policies']),
    );
  }

  static Future<AuthUserModel> getCurrentUser() async {
    return (await getCurrentSession()).user;
  }

  static Future<List<PlatformPolicy>> acceptPendingPolicies(
    List<PlatformPolicy> policies,
  ) async {
    final Map<String, String> versions = <String, String>{
      for (final PlatformPolicy policy in policies)
        policy.id.toString(): policy.version,
    };
    final Map<String, bool> acknowledgements = <String, bool>{
      for (final PlatformPolicy policy in policies)
        policy.id.toString(): true,
    };

    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('policies/accept'),
      <String, dynamic>{
        'policy_acceptances': versions,
        'policy_acknowledgements': acknowledgements,
      },
    );
    final int statusCode = response.statusCode ?? 500;
    if (statusCode < 200 || statusCode >= 300) {
      throw Exception(
        ApiClient.formatError(
          DioException.badResponse(
            statusCode: statusCode,
            requestOptions: response.requestOptions,
            response: response,
          ),
        ),
      );
    }

    final dynamic payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid policy acceptance response.');
    }
    return PlatformPolicy.parseList(payload['pending_policies']);
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
    ApiClient.invalidateReads();
    await WishlistService.clearLocalWishlist();
  }
}
