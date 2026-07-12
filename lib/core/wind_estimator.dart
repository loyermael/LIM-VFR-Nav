import 'dart:math' as math;

import '../models/flight_state.dart';
import '../models/wind.dart';
import 'units.dart';

/// Estimates wind from GPS ground-velocity samples collected while circling.
///
/// Physics: ground velocity = air velocity + wind. Over a full circle the air
/// velocity vectors (constant TAS, rotating heading) trace a circle centred on
/// the origin; adding the constant wind vector shifts that circle so its centre
/// sits at the **wind vector**. So we collect ground-velocity components
/// (vEast, vNorth) over a rolling window and, once the samples span enough of a
/// circle, least-squares-fit a circle: its centre is the wind (blowing-to)
/// vector and its radius is the TAS.
///
/// Feed it every [FlightState]; it returns the latest good estimate (or the
/// previous one until a fresh circle is available).
class WindEstimator {
  WindEstimator({this.window = const Duration(seconds: 60)});

  /// Rolling time window of samples to fit.
  final Duration window;

  final List<_Sample> _samples = [];
  WindEstimate? _last;
  WindEstimate? get last => _last;

  WindEstimate? add(FlightState f) {
    if (!f.hasFix || !f.hasValidTrack) return _last;

    final now = f.timestamp;
    final r = f.trackDeg * math.pi / 180.0;
    _samples.add(_Sample(
      f.groundSpeedMps * math.sin(r), // east
      f.groundSpeedMps * math.cos(r), // north
      f.trackDeg,
      now,
    ));
    _samples.removeWhere((s) => now.difference(s.t) > window);

    if (_samples.length < 8) return _last;

    // Need good angular coverage of the circle: at least 9 of 12 heading bins.
    final bins = List<bool>.filled(12, false);
    for (final s in _samples) {
      bins[((s.heading % 360) / 30).floor() % 12] = true;
    }
    if (bins.where((b) => b).length < 9) return _last;

    final fit = _fitCircle(_samples);
    if (fit == null) return _last;
    final (cE, cN, radius) = fit;

    final windTo = Units.normalizeBearing(math.atan2(cE, cN) * 180 / math.pi);
    _last = WindEstimate(
      fromDeg: Units.normalizeBearing(windTo + 180),
      speedKts: Units.mpsToKnots(math.sqrt(cE * cE + cN * cN)),
      tasKts: Units.mpsToKnots(radius),
      time: now,
    );
    return _last;
  }

  void reset() {
    _samples.clear();
    _last = null;
  }

  /// Kåsa algebraic circle fit. Returns (centreX, centreY, radius) or null if
  /// the points are degenerate (e.g. not actually turning).
  static (double, double, double)? _fitCircle(List<_Sample> pts) {
    // Solve for (A,B,C) minimising  x^2+y^2 = A*x + B*y + C.
    var sxx = 0.0, sxy = 0.0, syy = 0.0, sx = 0.0, sy = 0.0, s1 = 0.0;
    var sxz = 0.0, syz = 0.0, sz = 0.0; // z = x^2 + y^2
    for (final p in pts) {
      final x = p.vE, y = p.vN, z = p.vE * p.vE + p.vN * p.vN;
      sxx += x * x;
      sxy += x * y;
      syy += y * y;
      sx += x;
      sy += y;
      s1 += 1;
      sxz += x * z;
      syz += y * z;
      sz += z;
    }
    final m = [
      [sxx, sxy, sx],
      [sxy, syy, sy],
      [sx, sy, s1],
    ];
    final sol = _solve3(m, [sxz, syz, sz]);
    if (sol == null) return null;
    final cx = sol[0] / 2, cy = sol[1] / 2;
    final r2 = sol[2] + cx * cx + cy * cy;
    if (r2 <= 0) return null;
    return (cx, cy, math.sqrt(r2));
  }

  static List<double>? _solve3(List<List<double>> m, List<double> v) {
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
      if (a[pivot][col].abs() < 1e-9) return null;
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

class _Sample {
  final double vE;
  final double vN;
  final double heading;
  final DateTime t;
  _Sample(this.vE, this.vN, this.heading, this.t);
}
