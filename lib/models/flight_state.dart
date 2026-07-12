import 'package:latlong2/latlong.dart';

import '../core/units.dart';

/// A single GPS-derived snapshot of the aircraft state, recomputed continuously
/// from the [LocationService] stream and exposed in aviation units for the
/// instrument bar (GS / TRK / ALT) and the speed vector.
class FlightState {
  /// Current position, or null before the first fix.
  final LatLng? position;

  /// Ground speed in metres/second (as reported by GPS).
  final double groundSpeedMps;

  /// GPS course over ground, TRUE degrees. May be NaN when stationary.
  final double trackDeg;

  /// GPS (ellipsoidal) altitude in metres.
  final double altitudeMeters;

  /// Horizontal accuracy in metres (for a "GPS degraded" warning).
  final double accuracyMeters;

  final DateTime timestamp;

  const FlightState({
    required this.position,
    required this.groundSpeedMps,
    required this.trackDeg,
    required this.altitudeMeters,
    required this.accuracyMeters,
    required this.timestamp,
  });

  factory FlightState.noFix() => FlightState(
        position: null,
        groundSpeedMps: 0,
        trackDeg: double.nan,
        altitudeMeters: 0,
        accuracyMeters: double.infinity,
        timestamp: DateTime.now(),
      );

  bool get hasFix => position != null;

  /// Track is only meaningful once the aircraft is actually moving; GPS course
  /// is noise near-zero speed. Below ~3 kt we treat track as unknown.
  bool get hasValidTrack =>
      !trackDeg.isNaN && groundSpeedMps > 1.5; // ~3 kt

  double get groundSpeedKts => Units.mpsToKnots(groundSpeedMps);
  double get altitudeFeet => Units.metersToFeet(altitudeMeters);
}
