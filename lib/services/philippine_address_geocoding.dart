import 'package:latlong2/latlong.dart' show LatLng;

/// Builds progressively broader Philippines-only searches for buyer address pins.
class PhilippineAddressGeocoding {
  PhilippineAddressGeocoding._();

  static List<String> buildQueries({
    String searchText = '',
    String houseNumber = '',
    String street = '',
    String landmark = '',
    String barangay = '',
    String municipality = '',
    String province = '',
    String region = '',
  }) {
    final List<String> locality = _uniqueParts(<String>[
      barangay,
      municipality,
      province,
      region,
    ]);
    final List<String> context = _uniqueParts(<String>[
      ...locality,
      'Philippines',
    ]);
    final List<String> streetAddress = _uniqueParts(<String>[
      houseNumber,
      street,
      landmark,
    ]);
    final List<String> searchVariants = _searchVariants(searchText);
    final List<List<String>> candidates = <List<String>>[
      for (final String variant in searchVariants)
        <String>[variant, ...context],
      if (streetAddress.isNotEmpty) <String>[...streetAddress, ...context],
      for (final String variant in searchVariants)
        <String>[variant, 'Philippines'],
      <String>[
        _withoutBarangayPrefix(barangay),
        municipality,
        province,
        'Philippines',
      ],
      context,
      <String>[municipality, province, 'Philippines'],
    ];

    final Set<String> seen = <String>{};
    final List<String> queries = <String>[];
    for (final List<String> candidate in candidates) {
      final String query = _joinParts(candidate);
      final String searchableText = _normalize(
        query.replaceAll(RegExp(r'\bPhilippines\b', caseSensitive: false), ''),
      );
      if (searchableText.length < 3) continue;
      final String key = _normalize(query);
      if (key.isNotEmpty && seen.add(key)) queries.add(query);
    }
    return queries;
  }

  /// Reads GeoJSON/Mapbox-style `center` coordinates as well as Geoapify results.
  /// All supported payloads are converted from longitude/latitude to LatLng.
  static LatLng? locationFromResponse(dynamic payload) {
    if (payload is! Map) return null;

    final dynamic nestedData = payload['data'];
    if (nestedData is Map) {
      final LatLng? nestedLocation = locationFromResponse(nestedData);
      if (nestedLocation != null) return nestedLocation;
    }

    final dynamic features = payload['features'];
    if (features is List) {
      for (final dynamic feature in features) {
        if (feature is! Map) continue;
        final LatLng? center = _latLngFromPair(feature['center']);
        if (center != null) return center;
        final dynamic geometry = feature['geometry'];
        if (geometry is Map) {
          final LatLng? coordinates = _latLngFromPair(geometry['coordinates']);
          if (coordinates != null) return coordinates;
        }
      }
    }

    final dynamic results = payload['results'];
    if (results is List) {
      for (final dynamic result in results) {
        if (result is! Map) continue;
        final double? latitude = _number(result['lat'] ?? result['latitude']);
        final double? longitude = _number(
          result['lon'] ?? result['lng'] ?? result['longitude'],
        );
        final LatLng? location = _validLocation(latitude, longitude);
        if (location != null) return location;
      }
    }
    return null;
  }

  static String? errorMessageForResponse(int statusCode, dynamic payload) {
    if (statusCode >= 200 && statusCode < 300) return null;

    final String? serverMessage = payload is Map
        ? payload['message']?.toString().trim()
        : null;
    // A missed address is an empty result, not a failure of the service.
    // Let callers try the remaining locality queries.
    if ((statusCode == 404 || statusCode == 422) &&
        RegExp(
          r'^no matching address (was )?found[.!]?$',
          caseSensitive: false,
        ).hasMatch(serverMessage ?? '')) {
      return null;
    }
    if (statusCode == 404 &&
        serverMessage?.toLowerCase() == 'api endpoint not found.') {
      return 'Address search is temporarily unavailable. Tap the map to place your delivery pin.';
    }

    if (serverMessage?.isNotEmpty == true) return serverMessage;
    return 'Address search is temporarily unavailable. Please try again or pin the map manually.';
  }

  static List<String> _uniqueParts(Iterable<String> values) {
    final List<String> parts = <String>[];
    final Set<String> seen = <String>{};
    for (final String value in values) {
      final String part = value.trim().replaceAll(RegExp(r'\s+'), ' ');
      final String key = _normalize(part);
      if (key.isNotEmpty && seen.add(key)) parts.add(part);
    }
    return parts;
  }

  static List<String> _searchVariants(String searchText) {
    final String fullAddress = searchText
        .trim()
        .split(',')
        .map(_withoutBarangayPrefix)
        .where((String part) => part.isNotEmpty)
        .join(', ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (fullAddress.isEmpty) return <String>[];

    final List<String> variants = <String>[fullAddress];
    final List<String> commaParts = fullAddress
        .split(',')
        .map((String part) => part.trim())
        .where(
          (String part) => part.isNotEmpty && _normalize(part) != 'philippines',
        )
        .toList();
    final bool hasPostalCode =
        commaParts.length > 1 && RegExp(r'^\d{4,6}$').hasMatch(commaParts.last);
    final List<String> partsWithoutPostalCode = hasPostalCode
        ? commaParts.take(commaParts.length - 1).toList()
        : commaParts;
    if (hasPostalCode) {
      variants.add(partsWithoutPostalCode.join(', '));
    }
    // Keep at least city + province; never fall back to the whole country.
    for (int start = 1; start <= partsWithoutPostalCode.length - 2; start++) {
      variants.add(partsWithoutPostalCode.skip(start).join(', '));
    }
    return _uniqueParts(variants);
  }

  static String _withoutBarangayPrefix(String value) =>
      value.trim().replaceFirst(
        RegExp(r'^(?:brgy\.?|barangay)\s+', caseSensitive: false),
        '',
      );

  static String _joinParts(Iterable<String> values) {
    final List<String> parts = <String>[];
    for (final String value in values) {
      final String part = value
          .trim()
          .replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '')
          .replaceAll(RegExp(r'\s+'), ' ');
      final String normalizedPart = _normalize(part);
      if (normalizedPart.isEmpty) continue;
      final bool alreadyIncluded = parts.any((String existing) {
        final String normalizedExisting = _normalize(existing);
        return _containsPhrase(normalizedExisting, normalizedPart);
      });
      if (!alreadyIncluded) parts.add(part);
    }
    return parts.join(', ');
  }

  static bool _containsPhrase(String text, String phrase) =>
      (' $text ').contains(' $phrase ');

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static LatLng? _latLngFromPair(dynamic pair) {
    if (pair is! List || pair.length < 2) return null;
    return _validLocation(_number(pair[1]), _number(pair[0]));
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static LatLng? _validLocation(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    if (!latitude.isFinite || !longitude.isFinite) return null;
    if (latitude < -90 || latitude > 90) return null;
    if (longitude < -180 || longitude > 180) return null;
    return LatLng(latitude, longitude);
  }
}
