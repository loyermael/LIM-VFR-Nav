import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Planar geometry helpers on Lat/Lng, using a local equirectangular projection
/// (metres) around the query — accurate over the tens-of-NM scales VFR airspace
/// checks care about. Shared by airspace containment and proximity detection.
class Geo {
  Geo._();

  static const double _mPerDegLat = 111320.0;
  static double _mPerDegLon(double lat) =>
      _mPerDegLat * math.cos(lat * math.pi / 180.0);

  /// Ray-casting point-in-polygon (polygon as Lat/Lng ring, auto-closed).
  static bool pointInPolygon(LatLng p, List<LatLng> poly) {
    if (poly.length < 3) return false;
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].longitude, yi = poly[i].latitude;
      final xj = poly[j].longitude, yj = poly[j].latitude;
      final intersect = ((yi > p.latitude) != (yj > p.latitude)) &&
          (p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Distance (m) from point [p] to segment [a]–[b].
  static double segmentPointDistanceMeters(LatLng p, LatLng a, LatLng b) {
    final mLon = _mPerDegLon(a.latitude);
    double x(LatLng q) => q.longitude * mLon;
    double y(LatLng q) => q.latitude * _mPerDegLat;
    final px = x(p), py = y(p);
    final ax = x(a), ay = y(a);
    final bx = x(b), by = y(b);
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  }

  /// Do segments [a]–[b] and [c]–[d] cross? (orientation test)
  static bool segmentsIntersect(LatLng a, LatLng b, LatLng c, LatLng d) {
    double cross(LatLng o, LatLng p, LatLng q) =>
        (p.longitude - o.longitude) * (q.latitude - o.latitude) -
        (p.latitude - o.latitude) * (q.longitude - o.longitude);
    final d1 = cross(c, d, a);
    final d2 = cross(c, d, b);
    final d3 = cross(a, b, c);
    final d4 = cross(a, b, d);
    return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0));
  }

  /// Does segment [a]–[b] intersect the polygon (endpoint inside or edge cross)?
  static bool segmentIntersectsPolygon(LatLng a, LatLng b, List<LatLng> poly) {
    if (pointInPolygon(a, poly) || pointInPolygon(b, poly)) return true;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      if (segmentsIntersect(a, b, poly[j], poly[i])) return true;
    }
    return false;
  }
}
