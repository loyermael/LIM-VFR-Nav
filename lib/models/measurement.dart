import 'package:latlong2/latlong.dart';

import '../core/units.dart';

/// A two-point ruler laid on the chart (tap-to-measure). Reports distance in
/// nautical miles and TRUE bearing in degrees.
class Measurement {
  final LatLng from;
  final LatLng to;
  const Measurement(this.from, this.to);

  double get distanceNm => Units.metersToNm(Units.distanceMeters(from, to));
  double get bearingDeg => Units.bearingDeg(from, to);

  String get label =>
      '${distanceNm.toStringAsFixed(1)} NM  ·  ${Units.formatBearing(bearingDeg)}°';
}
