import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Requests location once when the app is first opened after installation.
/// Location features can still request permission later if the rider skips it.
class LocationPermissionOnboarding {
  LocationPermissionOnboarding._();

  static const _promptedKey = 'first_launch_location_permission_prompted_v1';

  static Future<void> requestIfFirstLaunch() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(_promptedKey) == true) return;

      final currentPermission = await Geolocator.checkPermission();
      if (currentPermission == LocationPermission.whileInUse ||
          currentPermission == LocationPermission.always ||
          currentPermission == LocationPermission.deniedForever) {
        await preferences.setBool(_promptedKey, true);
        return;
      }

      // Set this before opening the system prompt so returning to the app does
      // not cause the prompt to appear again on the next launch.
      await preferences.setBool(_promptedKey, true);
      await Geolocator.requestPermission();
    } catch (_) {
      // Permission onboarding must not prevent the app from starting. Existing
      // location features remain responsible for requesting access when needed.
    }
  }
}
