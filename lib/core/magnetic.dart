import 'package:latlong2/latlong.dart';

import 'units.dart';

/// Magnetic variation (declination) — TRUE ↔ MAGNETIC conversion.
///
/// A full WMM/IGRF model is overkill here; this is a coarse linear approximation
/// of easterly declination over **metropolitan France / western Europe** (epoch
/// ~2025), good to ~1°, with a gentle global fallback. Swap in a real WMM later
/// if sub-degree accuracy is needed. Positive = East.
class Magnetic {
  Magnetic._();

  /// Approximate easterly declination (degrees) at [p].
  static double declinationEast(LatLng p) {
    final lat = p.latitude, lon = p.longitude;
    // Fit over France box (42..51N, -5..8E): ~0° near Brittany, ~+2.5° in Alps.
    if (lat >= 41 && lat <= 52 && lon >= -6 && lon <= 9) {
      return (0.9 + 0.20 * lon + 0.05 * (lat - 46)).clamp(-3.0, 5.0);
    }
    // Elsewhere: a mild longitude-based guess (documented approximation).
    return (0.1 * lon).clamp(-20.0, 20.0);
  }

  /// TRUE bearing → MAGNETIC heading (what the pilot flies on the compass).
  static double trueToMagnetic(double trueDeg, LatLng at) =>
      Units.normalizeBearing(trueDeg - declinationEast(at));

  static double magneticToTrue(double magDeg, LatLng at) =>
      Units.normalizeBearing(magDeg + declinationEast(at));
}
