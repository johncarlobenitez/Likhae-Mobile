class AppConfig {
  AppConfig._();

  static const bool apiEnabled = bool.fromEnvironment(
    'API_ENABLED',
    defaultValue: false,
  );

  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://likhae.online',
  );
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '$webBaseUrl/api/v1',
  );
  static const String baseUrl = apiBaseUrl;
  static const String storageBaseUrl = '$webBaseUrl/storage';

  // Reverb speaks the Pusher WebSocket protocol. Keep these values as build
  // defines so the mobile app never needs a server-side .env file.
  static const String reverbAppKey = String.fromEnvironment(
    'REVERB_APP_KEY',
    defaultValue: '',
  );
  static const String reverbHost = String.fromEnvironment(
    'REVERB_HOST',
    defaultValue: 'likhae.online',
  );
  static const int reverbPort = int.fromEnvironment(
    'REVERB_PORT',
    defaultValue: 443,
  );
  static const String reverbScheme = String.fromEnvironment(
    'REVERB_SCHEME',
    defaultValue: 'https',
  );

  static bool get realtimeEnabled => apiEnabled && reverbAppKey.isNotEmpty;

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

    if (cleanEndpoint == 'api/v1') {
      return apiBaseUrl;
    }

    if (cleanEndpoint.startsWith('api/v1/')) {
      return '$apiBaseUrl/${cleanEndpoint.substring('api/v1/'.length)}';
    }

    return '${apiBaseUrl.replaceFirst(RegExp(r'/$'), '')}/$cleanEndpoint';
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
