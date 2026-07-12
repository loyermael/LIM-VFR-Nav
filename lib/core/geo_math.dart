import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:latlong2/latlong.dart';

import '../models/geo_calibration.dart';

/// Least-squares affine georeferencing.
///
/// A raster chart (PDF page / TIFF / scanned OACI map) is imported as a plain
/// image with pixel coordinates. Calibration ties >= 3 pixel points to real
/// world Lat/Lng. We fit an affine map  pixel -> (lng, lat):
///
///   lng = a*px + b*py + c
///   lat = d*px + e*py + f
///
/// An affine transform is exactly what a north-up-or-rotated, uniformly-scaled
/// scanned chart needs, and it is precisely representable by flutter_map's
/// [RotatedOverlayImage] (which takes three image corners). With more than 3
/// calibration points the fit is a least-squares best fit, which lets the pilot
/// improve accuracy by adding points.
class AffineGeoref {
  /// lng = a*px + b*py + c
  final double a, b, c;

  /// lat = d*px + e*py + f
  final double d, e, f;

  const AffineGeoref(this.a, this.b, this.c, this.d, this.e, this.f);

  LatLng pixelToLatLng(double px, double py) =>
      LatLng(d * px + e * py + f, a * px + b * py + c);

  /// Metres of ground per image pixel implied by this transform, evaluated at
  /// [atLatitude]. Handy to show the pilot the chart's ground resolution.
  double metersPerPixel(double atLatitude) {
    final mLon = _metersPerDegLon(atLatitude);
    final mLat = _metersPerDegLat;
    // Length of the +x pixel step on the ground.
    final ex = a * mLon, ey = d * mLat;
    return math.sqrt(ex * ex + ey * ey);
  }

  /// Metres per degree of latitude (spherical, constant to <0.3% over France).
  static const double _metersPerDegLat = 6371008.8 * math.pi / 180.0;

  /// Metres per degree of longitude, shrinking with latitude.
  static double _metersPerDegLon(double lat) =>
      _metersPerDegLat * math.cos(lat * math.pi / 180.0);

  /// Builds a georeference from the **printed scale plus a single anchor point**
  /// — the fast path for a standard north-up VFR/OACI sheet.
  ///
  /// [metersPerPixel] comes from the scale and the raster resolution
  /// (`0.0254 * scaleDenominator / pixelsPerInch`). [rotationDeg] is the azimuth
  /// (TRUE °) that the chart's "up" points to — 0 for a north-up chart; provide
  /// it only if the sheet is deliberately rotated. The map is treated as locally
  /// flat around the anchor, which is amply accurate for VFR situational use
  /// across a single sheet.
  static AffineGeoref fromScaleAnchor({
    required Offset anchorPixel,
    required LatLng anchorWorld,
    required double metersPerPixel,
    double rotationDeg = 0,
  }) {
    final theta = rotationDeg * math.pi / 180.0;
    final cosT = math.cos(theta), sinT = math.sin(theta);
    final mLon = _metersPerDegLon(anchorWorld.latitude);
    final mLat = _metersPerDegLat;
    final cx = anchorPixel.dx, cy = anchorPixel.dy;
    final mpp = metersPerPixel;

    // See derivation in the design notes: east/north as linear fns of px,py.
    final a = mpp * cosT / mLon;
    final b = -mpp * sinT / mLon;
    final d = -mpp * sinT / mLat;
    final e = -mpp * cosT / mLat;
    final c = anchorWorld.longitude - a * cx - b * cy;
    final f = anchorWorld.latitude - d * cx - e * cy;
    return AffineGeoref(a, b, c, d, e, f);
  }

  /// Fit from calibration points. Throws [ArgumentError] if fewer than 3
  /// non-degenerate points are supplied.
  static AffineGeoref fit(List<CalibrationPoint> points) {
    if (points.length < 3) {
      throw ArgumentError('Need at least 3 calibration points, got '
          '${points.length}.');
    }
    // Normal equations for design matrix rows [px, py, 1].
    // Accumulate A^T A (symmetric 3x3) and A^T y for both outputs.
    var sxx = 0.0, sxy = 0.0, sx = 0.0, syy = 0.0, sy = 0.0, s1 = 0.0;
    var tLngX = 0.0, tLngY = 0.0, tLng1 = 0.0;
    var tLatX = 0.0, tLatY = 0.0, tLat1 = 0.0;

    for (final p in points) {
      final px = p.pixel.dx, py = p.pixel.dy;
      sxx += px * px;
      sxy += px * py;
      sx += px;
      syy += py * py;
      sy += py;
      s1 += 1.0;

      tLngX += px * p.world.longitude;
      tLngY += py * p.world.longitude;
      tLng1 += p.world.longitude;

      tLatX += px * p.world.latitude;
      tLatY += py * p.world.latitude;
      tLat1 += p.world.latitude;
    }

    final ata = <List<double>>[
      [sxx, sxy, sx],
      [sxy, syy, sy],
      [sx, sy, s1],
    ];

    final lng = _solve3(ata, [tLngX, tLngY, tLng1]);
    final lat = _solve3(ata, [tLatX, tLatY, tLat1]);
    if (lng == null || lat == null) {
      throw ArgumentError('Calibration points are collinear/degenerate; '
          'pick 3 points that form a triangle across the chart.');
    }
    return AffineGeoref(lng[0], lng[1], lng[2], lat[0], lat[1], lat[2]);
  }

  /// The four image corners (in Lat/Lng) for an image of [imageWidth] x
  /// [imageHeight] pixels — ready to hand to [RotatedOverlayImage].
  /// Pixel origin is top-left, +y downwards (image convention).
  ImageCorners cornersFor(double imageWidth, double imageHeight) => ImageCorners(
        topLeft: pixelToLatLng(0, 0),
        topRight: pixelToLatLng(imageWidth, 0),
        bottomLeft: pixelToLatLng(0, imageHeight),
        bottomRight: pixelToLatLng(imageWidth, imageHeight),
      );

  Map<String, double> toJson() =>
      {'a': a, 'b': b, 'c': c, 'd': d, 'e': e, 'f': f};

  factory AffineGeoref.fromJson(Map<String, dynamic> j) => AffineGeoref(
        (j['a'] as num).toDouble(),
        (j['b'] as num).toDouble(),
        (j['c'] as num).toDouble(),
        (j['d'] as num).toDouble(),
        (j['e'] as num).toDouble(),
        (j['f'] as num).toDouble(),
      );

  /// Solves the 3x3 system m*x = v by Gaussian elimination with partial
  /// pivoting. Returns null when the matrix is singular (degenerate points).
  static List<double>? _solve3(List<List<double>> m, List<double> v) {
    // Work on a copy of the augmented matrix.
    final a = [
      [m[0][0], m[0][1], m[0][2], v[0]],
      [m[1][0], m[1][1], m[1][2], v[1]],
      [m[2][0], m[2][1], m[2][2], v[2]],
    ];
    for (var col = 0; col < 3; col++) {
      var pivot = col;
      for (var r = col + 1; r < 3; r++) {
        if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
      }
      if (a[pivot][col].abs() < 1e-12) return null; // singular
      final tmp = a[col];
      a[col] = a[pivot];
      a[pivot] = tmp;

      for (var r = 0; r < 3; r++) {
        if (r == col) continue;
        final factor = a[r][col] / a[col][col];
        for (var k = col; k < 4; k++) {
          a[r][k] -= factor * a[col][k];
        }
      }
    }
    return [a[0][3] / a[0][0], a[1][3] / a[1][1], a[2][3] / a[2][2]];
  }
}

class ImageCorners {
  final LatLng topLeft;
  final LatLng topRight;
  final LatLng bottomLeft;
  final LatLng bottomRight;
  const ImageCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });
}
