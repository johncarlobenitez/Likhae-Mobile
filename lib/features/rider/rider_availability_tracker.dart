import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/config/app_config.dart';
import '../../services/rider_mobile_service.dart';
import 'profile/rider_profile_screen.dart';

/// Keeps an online local rider's dispatch location fresh while the app is open.
class RiderAvailabilityTracker extends StatefulWidget {
  final Widget child;
  final RiderProfileData? profile;

  const RiderAvailabilityTracker({
    super.key,
    required this.child,
    this.profile,
  });

  @override
  State<RiderAvailabilityTracker> createState() =>
      _RiderAvailabilityTrackerState();
}

class _RiderAvailabilityTrackerState extends State<RiderAvailabilityTracker>
    with WidgetsBindingObserver {
  static const Duration _refreshInterval = Duration(minutes: 5);

  Timer? _timer;
  bool _requestInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      _refreshInterval,
      (_) => unawaited(_syncLocation()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_syncLocation(profile: widget.profile));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncLocation());
    }
  }

  Future<void> _syncLocation({RiderProfileData? profile}) async {
    if (!mounted ||
        !AppConfig.apiEnabled ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        _requestInFlight) {
      return;
    }

    _requestInFlight = true;
    try {
      final RiderProfileData activeProfile =
          profile ?? await RiderMobileService.fetchProfile();
      if (!activeProfile.isOnline || !activeProfile.isLocalBarangay) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;

      final LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      Position? position = await Geolocator.getLastKnownPosition().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (position == null ||
          DateTime.now().difference(position.timestamp) >
              const Duration(minutes: 5)) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        ).timeout(const Duration(seconds: 12));
      }
      if (position == null || !mounted) return;
      await RiderMobileService.updateAvailabilityLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // Leave the last saved status and location intact during temporary errors.
    } finally {
      _requestInFlight = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
