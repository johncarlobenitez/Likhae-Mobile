import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/rider/profile/rider_profile_screen.dart';

void main() {
  test(
    'van riders can use availability controls without location tracking',
    () {
      final profile = RiderProfileData.fromApi({
        'user': {'id': 12, 'name': 'Van Rider'},
        'rider': {'vehicle_type': 'Van', 'is_online': true},
      });

      expect(profile.isVan, isTrue);
      expect(profile.supportsAvailabilityStatus, isTrue);
      expect(profile.isOnline, isTrue);
      expect(profile.isLocalBarangay, isFalse);
    },
  );

  test('closed vans do not use local rider availability controls', () {
    final profile = RiderProfileData.fromApi({
      'user': {'id': 13, 'name': 'Closed Van Rider'},
      'rider': {'vehicle_type': 'closed_van'},
    });

    expect(profile.isVan, isFalse);
    expect(profile.supportsAvailabilityStatus, isFalse);
  });
}
