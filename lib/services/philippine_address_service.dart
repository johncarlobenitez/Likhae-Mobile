import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import '../features/auth/register_screen.dart';

class PhilippineAddressService {
  PhilippineAddressService._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.resolveApiUrl('address/philippines'),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: <String, String>{'Accept': 'application/json'},
    ),
  );

  static final Dio _psgcDio = Dio(
    BaseOptions(
      baseUrl: 'https://psgc.gitlab.io/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: <String, String>{'Accept': 'application/json'},
    ),
  );

  static Future<List<AddressOption>> fetchRegions() async {
    return _fetchOptions('/regions');
  }

  static Future<List<AddressOption>> fetchProvinces(String regionCode) async {
    return _fetchOptions('/regions/${Uri.encodeComponent(regionCode)}/provinces');
  }

  static Future<List<AddressOption>> fetchMunicipalities(
    String provinceCode,
  ) async {
    return _fetchOptions(
      '/provinces/${Uri.encodeComponent(provinceCode)}/municipalities',
    );
  }

  static Future<List<AddressOption>> fetchBarangays(
    String municipalityCode,
  ) async {
    return _fetchOptions(
      '/municipalities/${Uri.encodeComponent(municipalityCode)}/barangays',
    );
  }

  static Future<String?> fetchPostalCode({
    required String municipalityCode,
    required String barangayCode,
    required String provinceName,
    required String municipalityName,
  }) async {
    final Response<dynamic> response = await _dio.get(
      '/postal-code',
      queryParameters: <String, dynamic>{
        'municipality': municipalityCode,
        'province_name': provinceName,
        'municipality_name': municipalityName,
        'barangay': barangayCode,
      },
    );
    final dynamic data = response.data;
    if (data is Map && data['postal_code'] != null) {
      return data['postal_code'].toString();
    }
    return null;
  }

  static Future<List<AddressOption>> _fetchOptions(String path) async {
    try {
      final Response<dynamic> response = await _dio.get(path);
      return _parseOptions(response.data);
    } catch (_) {
      // Keep the registration form usable while the Laravel address route is
      // being deployed. The public PSGC endpoint has the same code/name data.
      return _fetchFromPsgc(path);
    }
  }

  static List<AddressOption> _parseOptions(dynamic data) {
    if (data is Map && data['data'] is List) {
      data = data['data'];
    }
    if (data is! List) {
      throw const FormatException('Invalid Philippine address response.');
    }

    return data.whereType<Map>().map((Map item) {
      final Map<String, dynamic> row = Map<String, dynamic>.from(item);
      return AddressOption(
        code: (row['code'] ?? '').toString(),
        name: (row['name'] ?? '').toString(),
      );
    }).where((AddressOption option) {
      return option.code.isNotEmpty && option.name.isNotEmpty;
    }).toList(growable: false);
  }

  static Future<List<AddressOption>> _fetchFromPsgc(String path) async {
    final String psgcPath = path
        .replaceFirst('/cities-municipalities/', '/cities-municipalities/')
        .replaceFirst('/municipalities/', '/cities-municipalities/')
        .replaceFirst('/municipalities', '/cities-municipalities');
    final Response<dynamic> response = await _psgcDio.get(
      psgcPath.endsWith('/') ? psgcPath : '$psgcPath/',
      options: Options(receiveTimeout: const Duration(seconds: 15)),
    );
    return _parseOptions(response.data);
  }
}
