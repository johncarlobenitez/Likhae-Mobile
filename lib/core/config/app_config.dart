class AppConfig {
  AppConfig._();

  /// Set to false while layouts are being finalized without backend integration.
  static const bool apiEnabled = false;

  static const String webBaseUrl = 'https://likhae.online';
  static const String baseUrl = '$webBaseUrl/api/v1';
  static const String apiBaseUrl = baseUrl;
  static const String storageBaseUrl = '$webBaseUrl/storage';

  static String resolveApiUrl(String endpoint) {
    final String normalized = endpoint.trim();

    if (normalized.isEmpty) {
      return apiBaseUrl;
    }

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    final String cleanEndpoint = normalized.startsWith('/')
        ? normalized.substring(1)
        : normalized;

    if (cleanEndpoint.startsWith('api/v1')) {
      return '$webBaseUrl/$cleanEndpoint';
    }

    return '$apiBaseUrl/$cleanEndpoint';
  }

  static String resolveMediaUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }

    final String normalized = value.trim();

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    final String withoutLeadingSlash = normalized.startsWith('/')
        ? normalized.substring(1)
        : normalized;

    final List<String> storagePrefixes = <String>[
      'storage/',
      'uploads/',
      'images/',
      'public/',
      'media/',
    ];

    for (final prefix in storagePrefixes) {
      if (withoutLeadingSlash.startsWith(prefix)) {
        return '$webBaseUrl/$withoutLeadingSlash';
      }
    }

    if (withoutLeadingSlash.startsWith('storage') ||
        withoutLeadingSlash.startsWith('uploads') ||
        withoutLeadingSlash.startsWith('images') ||
        withoutLeadingSlash.startsWith('public') ||
        withoutLeadingSlash.startsWith('media')) {
      return '$webBaseUrl/$withoutLeadingSlash';
    }

    if (normalized.startsWith('/')) {
      return '$webBaseUrl$normalized';
    }

    return '$storageBaseUrl/$withoutLeadingSlash';
  }
}