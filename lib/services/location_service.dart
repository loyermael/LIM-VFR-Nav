import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/flight_state.dart';

/// Thin wrapper over `geolocator` that yields [FlightState] snapshots.
///
/// Everything here works with the device GPS chip only — no network — so the
/// moving map keeps functioning in-flight with no connectivity, per the
/// offline requirement.
class LocationService {
  StreamSubscription<Position>? _sub;

  /// Requests permission (once) and returns a broadcast stream of fixes.
  /// Emits [FlightState.noFix] first so the UI has something to render before
  /// the GPS warms up.
  Stream<FlightState> stream() async* {
    yield FlightState.noFix();

    final ok = await _ensurePermission();
    if (!ok) {
      // Keep emitting no-fix; the UI shows a "no GPS permission" banner.
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0, // we want a smooth in-flight update rate
    );

    yield* Geolocator.getPositionStream(locationSettings: settings)
        .map(_toFlightState);
  }

  FlightState _toFlightState(Position p) => FlightState(
        position: LatLng(p.latitude, p.longitude),
        groundSpeedMps: p.speed.isNaN ? 0 : p.speed,
        trackDeg: p.heading,
        altitudeMeters: p.altitude,
        accuracyMeters: p.accuracy,
        timestamp: p.timestamp,
      );

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  void dispose() => _sub?.cancel();
}
