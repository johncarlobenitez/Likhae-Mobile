import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:likhae/services/philippine_address_geocoding.dart';

void main() {
  group('PhilippineAddressGeocoding.buildQueries', () {
    test(
      'searches Aplaya without the Brgy prefix before broadening to Pila',
      () {
        final queries = PhilippineAddressGeocoding.buildQueries(
          searchText: 'Brgy Aplaya, Pila, Laguna',
        );
        expect(queries.first, 'Aplaya, Pila, Laguna, Philippines');
        expect(queries, contains('Aplaya, Pila, Laguna, Philippines'));
        expect(queries, contains('Pila, Laguna, Philippines'));
        expect(
          queries.indexOf('Aplaya, Pila, Laguna, Philippines'),
          lessThan(queries.indexOf('Pila, Laguna, Philippines')),
        );
        expect(queries, isNot(contains('Philippines')));
      },
    );

    test('tries the structured barangay without region or abbreviation', () {
      final queries = PhilippineAddressGeocoding.buildQueries(
        barangay: 'Brgy. Aplaya',
        municipality: 'Pila',
        province: 'Laguna',
        region: 'Region IV-A (CALABARZON)',
      );
      expect(queries, contains('Aplaya, Pila, Laguna, Philippines'));
    });

    test('uses the freeform address and full saved address details', () {
      final List<String> queries = PhilippineAddressGeocoding.buildQueries(
        searchText: 'Purok 3',
        houseNumber: '12',
        street: 'Mabini Street',
        landmark: 'Near the public school',
        barangay: 'San Antonio',
        municipality: 'Pagsanjan',
        province: 'Laguna',
        region: 'CALABARZON',
      );

      expect(queries.first, contains('Purok 3'));
      expect(queries.first, contains('Pagsanjan'));
      expect(
        queries.any(
          (String query) =>
              query.contains('12') &&
              query.contains('Mabini Street') &&
              query.contains('Near the public school'),
        ),
        isTrue,
      );
      expect(
        queries.every((String query) => query.contains('Philippines')),
        isTrue,
      );
    });

    test('avoids repeating selected place names already in the search', () {
      final List<String> queries = PhilippineAddressGeocoding.buildQueries(
        searchText: 'San Antonio, Pagsanjan, Laguna',
        barangay: 'San Antonio',
        municipality: 'Pagsanjan',
        province: 'Laguna',
      );

      expect(queries.first, 'San Antonio, Pagsanjan, Laguna, Philippines');
    });

    test('uses structured address fields when the map search is empty', () {
      final List<String> queries = PhilippineAddressGeocoding.buildQueries(
        houseNumber: '12',
        street: 'Mabini Street',
        barangay: 'San Antonio',
        municipality: 'Pagsanjan',
        province: 'Laguna',
      );

      expect(queries.first, contains('Mabini Street'));
      expect(queries.first, contains('San Antonio'));
    });

    test(
      'falls back from a full rider address to postal-free locality searches',
      () {
        final List<String> queries = PhilippineAddressGeocoding.buildQueries(
          searchText: '1 Sample Street, Masico, Pila, Laguna, 4010',
        );

        expect(
          queries.first,
          '1 Sample Street, Masico, Pila, Laguna, 4010, Philippines',
        );
        expect(
          queries.any(
            (String query) =>
                query == '1 Sample Street, Masico, Pila, Laguna, Philippines',
          ),
          isTrue,
        );
        expect(queries, contains('Masico, Pila, Laguna, Philippines'));
      },
    );
  });

  group('PhilippineAddressGeocoding.locationFromResponse', () {
    test(
      'converts longitude-first GeoJSON coordinates to latitude-first LatLng',
      () {
        final LatLng? location =
            PhilippineAddressGeocoding.locationFromResponse(<String, dynamic>{
              'features': <Map<String, dynamic>>[
                <String, dynamic>{
                  'center': <double>[121.4558, 14.2728],
                },
              ],
            });

        expect(location, const LatLng(14.2728, 121.4558));
      },
    );

    test('rejects invalid coordinate values', () {
      expect(
        PhilippineAddressGeocoding.locationFromResponse(<String, dynamic>{
          'features': <Map<String, dynamic>>[
            <String, dynamic>{
              'center': <String>['NaN', '14'],
            },
          ],
        }),
        isNull,
      );
    });
  });

  test('explains when the Laravel address map route is missing', () {
    final String? message = PhilippineAddressGeocoding.errorMessageForResponse(
      404,
      <String, dynamic>{
        'message': 'API endpoint not found.',
        'path': 'api/v1/maps/geocode',
      },
    );

    expect(message, contains('api/v1/maps/geocode'));
    expect(message, contains('API_BASE_URL'));
  });

  test('a no-match response allows the next query, but outages do not', () {
    for (final status in [404, 422]) {
      expect(
        PhilippineAddressGeocoding.errorMessageForResponse(status, {
          'message': 'No matching address was found.',
        }),
        isNull,
      );
    }
    expect(
      PhilippineAddressGeocoding.errorMessageForResponse(503, {
        'message': 'The map service is temporarily unavailable.',
      }),
      isNotNull,
    );
  });
}
