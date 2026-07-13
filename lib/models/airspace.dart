import 'package:latlong2/latlong.dart';

import '../core/geometry.dart';
import '../core/units.dart';

/// Airspace category (subset relevant to French/European VFR).
enum AirspaceClass { ctr, tma, prohibited, restricted, danger, other }

/// A controlled or special-use airspace volume. Geometry is either a circle
/// (centre + radius) or a polygon. Vertical limits are stored in feet AMSL
/// (a simplification — real limits mix AGL/FL/AMSL; convert upstream).
class Airspace {
  final String name;
  final AirspaceClass klass;
  final LatLng? center;
  final double? radiusNm;
  final List<LatLng> polygon;
  final double floorFt; // AMSL
  final double ceilingFt; // AMSL

  const Airspace({
    required this.name,
    required this.klass,
    this.center,
    this.radiusNm,
    this.polygon = const [],
    required this.floorFt,
    required this.ceilingFt,
  });

  bool get isCircle => center != null && radiusNm != null;

  /// Entering these without clearance is the safety concern (alerts key off it).
  bool get isControlledOrForbidden =>
      klass == AirspaceClass.ctr ||
      klass == AirspaceClass.tma ||
      klass == AirspaceClass.prohibited ||
      klass == AirspaceClass.restricted;

  /// Horizontal containment of [p].
  bool containsHorizontal(LatLng p) {
    if (isCircle) {
      return Units.distanceMeters(center!, p) <= Units.nmToMeters(radiusNm!);
    }
    return Geo.pointInPolygon(p, polygon);
  }

  /// Whether [altFt] falls within the vertical band (with an optional [marginFt]
  /// to catch "about to be inside" vertically).
  bool containsVertical(double altFt, {double marginFt = 0}) =>
      altFt >= floorFt - marginFt && altFt <= ceilingFt + marginFt;

  bool contains(LatLng p, double altFt, {double marginFt = 0}) =>
      containsHorizontal(p) && containsVertical(altFt, marginFt: marginFt);

  /// Does the horizontal segment [a]–[b] touch this airspace footprint?
  bool crossedBySegment(LatLng a, LatLng b) {
    if (isCircle) {
      return Geo.segmentPointDistanceMeters(center!, a, b) <=
          Units.nmToMeters(radiusNm!);
    }
    return Geo.segmentIntersectsPolygon(a, b, polygon);
  }

  /// A representative point for labelling / distance sampling.
  LatLng get anchor =>
      center ??
      (polygon.isEmpty
          ? const LatLng(0, 0)
          : LatLng(
              polygon.map((e) => e.latitude).reduce((a, b) => a + b) /
                  polygon.length,
              polygon.map((e) => e.longitude).reduce((a, b) => a + b) /
                  polygon.length,
            ));
}
