import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:lim_vfr_nav/core/geo_math.dart';
import 'package:lim_vfr_nav/core/glide_math.dart';
import 'package:lim_vfr_nav/core/units.dart';
import 'package:lim_vfr_nav/core/wind_estimator.dart';
import 'package:lim_vfr_nav/models/flight_state.dart';
import 'package:lim_vfr_nav/models/geo_calibration.dart';

void main() {
  group('Units', () {
    test('metric -> aviation conversions', () {
      expect(Units.metersToNm(1852), closeTo(1.0, 1e-9));
      expect(Units.mpsToKnots(1), closeTo(1.9438, 1e-3));
      expect(Units.metersToFeet(1000), closeTo(3280.84, 1e-1));
    });

    test('bearing is normalised and formatted to 3 digits', () {
      expect(Units.normalizeBearing(-90), closeTo(270, 1e-9));
      expect(Units.formatBearing(47.4), '047');
      expect(Units.formatBearing(360), '000');
    });

    test('distance + destination round-trip', () {
      const start = LatLng(45.0, 4.0);
      final dest = Units.destination(start, 90, Units.nmToMeters(10));
      expect(Units.metersToNm(Units.distanceMeters(start, dest)),
          closeTo(10.0, 0.01));
      // Due east should barely change latitude and increase longitude.
      expect(dest.latitude, closeTo(45.0, 0.05));
      expect(dest.longitude, greaterThan(4.0));
    });
  });

  group('AffineGeoref', () {
    test('recovers a known affine from tie-points', () {
      // Truth: lng = 0.001*px + 0*py + 4 ; lat = 0*px - 0.001*py + 46
      LatLng truth(double px, double py) =>
          LatLng(46 - 0.001 * py, 4 + 0.001 * px);

      final pts = [
        CalibrationPoint(const Offset(0, 0), truth(0, 0)),
        CalibrationPoint(const Offset(1000, 0), truth(1000, 0)),
        CalibrationPoint(const Offset(0, 800), truth(0, 800)),
        CalibrationPoint(const Offset(1000, 800), truth(1000, 800)),
      ];

      final fit = AffineGeoref.fit(pts);
      final p = fit.pixelToLatLng(500, 400);
      expect(p.longitude, closeTo(4.5, 1e-6));
      expect(p.latitude, closeTo(45.6, 1e-6));

      final corners = fit.cornersFor(1000, 800);
      expect(corners.topLeft.latitude, closeTo(46.0, 1e-6));
      expect(corners.bottomRight.longitude, closeTo(5.0, 1e-6));
    });

    test('fromScaleAnchor: north-up, single point', () {
      final g = AffineGeoref.fromScaleAnchor(
        anchorPixel: const Offset(0, 0),
        anchorWorld: const LatLng(45, 5),
        metersPerPixel: 100,
      );
      // 10 px east -> +1000 m east.
      final east = g.pixelToLatLng(10, 0);
      expect(east.latitude, closeTo(45.0, 1e-6));
      expect(east.longitude, closeTo(5.0127185, 1e-4));
      // 10 px down -> 1000 m south (latitude decreases).
      final south = g.pixelToLatLng(0, 10);
      expect(south.longitude, closeTo(5.0, 1e-6));
      expect(south.latitude, closeTo(44.9910068, 1e-4));
      // Ground resolution should read back as the input scale.
      expect(g.metersPerPixel(45), closeTo(100, 1e-3));
    });

    test('rejects fewer than 3 points', () {
      expect(
        () => AffineGeoref.fit([
          CalibrationPoint(const Offset(0, 0), const LatLng(0, 0)),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects collinear points', () {
      final line = [
        CalibrationPoint(const Offset(0, 0), const LatLng(46, 4)),
        CalibrationPoint(const Offset(10, 10), const LatLng(46.01, 4.01)),
        CalibrationPoint(const Offset(20, 20), const LatLng(46.02, 4.02)),
      ];
      expect(() => AffineGeoref.fit(line), throwsArgumentError);
    });
  });

  group('glideRangePolygon', () {
    const center = LatLng(45, 5);
    // 1000 m AGL at glide ratio 40 -> 40 km still-air range.
    const altAgl = 1000.0, ratio = 40.0;
    const r0 = altAgl * ratio;

    test('still air is a circle of radius height*ratio', () {
      final poly = glideRangePolygon(
          center: center, altAglMeters: altAgl, glideRatio: ratio);
      for (final p in poly) {
        expect(Units.distanceMeters(center, p), closeTo(r0, r0 * 0.001));
      }
    });

    test('wind stretches the footprint downwind', () {
      // Wind FROM 270° (west) blows TO 090° (east).
      const windToDeg = 90.0;
      final poly = glideRangePolygon(
        center: center,
        altAglMeters: altAgl,
        glideRatio: ratio,
        tasMps: Units.knotsToMps(80),
        windToDeg: windToDeg,
        windMps: Units.knotsToMps(20),
      );
      final east = poly.reduce((a, b) => a.longitude > b.longitude ? a : b);
      final west = poly.reduce((a, b) => a.longitude < b.longitude ? a : b);
      final dEast = Units.distanceMeters(center, east);
      final dWest = Units.distanceMeters(center, west);
      expect(dEast, greaterThan(r0)); // downwind: farther
      expect(dWest, lessThan(r0)); // upwind: shorter
    });
  });

  group('WindEstimator', () {
    test('recovers wind from a full synthetic circle', () {
      const tas = 30.0; // m/s
      const windEast = 10.0; // wind blowing TO the east => FROM 270°
      final est = WindEstimator();
      var t = DateTime(2026, 1, 1);
      WindEstimate? last;
      for (var deg = 0; deg < 360; deg += 15) {
        final h = deg * math.pi / 180;
        final e = tas * math.sin(h) + windEast; // ground velocity east
        final n = tas * math.cos(h); // ground velocity north
        final gs = math.sqrt(e * e + n * n);
        final track = Units.normalizeBearing(math.atan2(e, n) * 180 / math.pi);
        t = t.add(const Duration(seconds: 2));
        last = est.add(FlightState(
          position: const LatLng(45, 5),
          groundSpeedMps: gs,
          trackDeg: track,
          altitudeMeters: 1000,
          accuracyMeters: 5,
          timestamp: t,
        ));
      }
      expect(last, isNotNull);
      expect(last!.fromDeg, closeTo(270, 3));
      expect(last.speedKts, closeTo(Units.mpsToKnots(windEast), 1));
      expect(last.tasKts, closeTo(Units.mpsToKnots(tas), 1));
    });
  });
}
