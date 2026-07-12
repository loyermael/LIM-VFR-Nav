import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'units.dart';

/// Computes the wind-corrected glide-range footprint around [center].
///
/// Model (standard glide-computer approximation):
///   still-air range  R0 = height_AGL × glideRatio
///   air time         t  = R0 / V           (V = best-glide TAS)
///   ground range(θ)  = t · (V + W·cos(θ − windToDeg))
///                    = R0 · (1 + (W/V)·cos(θ − windToDeg))
///
/// So the footprint is a circle of radius R0 in still air, stretched downwind
/// into the classic "egg" when a wind is supplied. Flying straight along each
/// ground bearing θ is assumed (no drift solution) — plenty for a situational
/// reachability overlay. Returns a closed ring of [steps] Lat/Lng points.
///
/// [tasMps] null or ≤ 1 → wind ignored (plain circle). Upwind values that would
/// go negative (wind stronger than airspeed) are clamped to zero.
List<LatLng> glideRangePolygon({
  required LatLng center,
  required double altAglMeters,
  required double glideRatio,
  double? tasMps,
  double windToDeg = 0,
  double windMps = 0,
  int steps = 72,
}) {
  final r0 = altAglMeters * glideRatio;
  final useWind = tasMps != null && tasMps > 1 && windMps > 0;
  final pts = <LatLng>[];
  for (var i = 0; i < steps; i++) {
    final theta = 360.0 * i / steps;
    var r = r0;
    if (useWind) {
      final delta = (theta - windToDeg) * math.pi / 180.0;
      r = r0 * (1 + (windMps / tasMps) * math.cos(delta));
      if (r < 0) r = 0;
    }
    pts.add(Units.destination(center, theta, r));
  }
  return pts;
}
