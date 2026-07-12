import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Aviation unit conversions and great-circle geometry.
///
/// All angles are in degrees on the public API; radians stay internal.
/// Distances arrive in metres (SI, as reported by the GPS/geolocator) and are
/// converted to the aviation units the pilot expects (NM, kt, ft).
class Units {
  Units._();

  static const double _earthRadiusM = 6371008.8; // mean Earth radius
  static const double metersPerNauticalMile = 1852.0;
  static const double feetPerMeter = 3.28084;
  static const double knotsPerMeterPerSecond = 1.9438444924406; // 3600/1852

  static double metersToNm(double m) => m / metersPerNauticalMile;
  static double nmToMeters(double nm) => nm * metersPerNauticalMile;
  static double metersToFeet(double m) => m * feetPerMeter;
  static double mpsToKnots(double mps) => mps * knotsPerMeterPerSecond;
  static double knotsToMps(double kt) => kt / knotsPerMeterPerSecond;
  static double feetToMeters(double ft) => ft / feetPerMeter;

  static double _rad(double deg) => deg * math.pi / 180.0;
  static double _deg(double rad) => rad * 180.0 / math.pi;

  /// Normalise any bearing into the [0, 360) range.
  static double normalizeBearing(double deg) {
    final b = deg % 360.0;
    return b < 0 ? b + 360.0 : b;
  }

  /// Great-circle (haversine) distance in metres between two positions.
  static double distanceMeters(LatLng a, LatLng b) {
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * _earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// Initial TRUE bearing (degrees) from [a] to [b].
  static double bearingDeg(LatLng a, LatLng b) {
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return normalizeBearing(_deg(math.atan2(y, x)));
  }

  /// Point reached from [from] travelling [distanceMeters] along a TRUE
  /// [bearingDeg]. Used to project the aircraft's speed vector and to place
  /// distance-ring centres. Spherical model — accurate to a few metres over
  /// the tens-of-NM ranges VFR navigation cares about.
  static LatLng destination(LatLng from, double bearingDeg, double distanceMeters) {
    final dr = distanceMeters / _earthRadiusM;
    final brng = _rad(bearingDeg);
    final lat1 = _rad(from.latitude);
    final lon1 = _rad(from.longitude);

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(dr) +
          math.cos(lat1) * math.sin(dr) * math.cos(brng),
    );
    final lon2 = lon1 +
        math.atan2(
          math.sin(brng) * math.sin(dr) * math.cos(lat1),
          math.cos(dr) - math.sin(lat1) * math.sin(lat2),
        );
    return LatLng(_deg(lat2), _deg(lon2));
  }

  /// Formats a bearing as a zero-padded 3-digit heading string, e.g. "047".
  static String formatBearing(double deg) =>
      normalizeBearing(deg).round().toString().padLeft(3, '0');
}
