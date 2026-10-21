import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/config/app_config.dart';
import '../../services/rider_mobile_service.dart';

/// Keeps an online local rider's dispatch location fresh while the app is open.
class RiderAvailabilityTracker extends StatefulWidget {
  final Widget child;

  const RiderAvailabilityTracker({super.key, required this.child});

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
    unawaited(_syncLocation());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncLocation());
    }
  }

  Future<void> _syncLocation() async {
    if (!mounted ||
        !AppConfig.apiEnabled ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        _requestInFlight) {
      return;
    }

    _requestInFlight = true;
    try {
      final profile = await RiderMobileService.fetchProfile();
      if (!profile.isOnline || !profile.supportsAvailabilityStatus) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;

      final LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
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
