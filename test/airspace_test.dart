import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:lim_vfr_nav/core/airspace_geo.dart';
import 'package:lim_vfr_nav/core/geometry.dart';
import 'package:lim_vfr_nav/core/magnetic.dart';
import 'package:lim_vfr_nav/models/airspace.dart';

void main() {
  const ctr = Airspace(
    name: 'CTR TEST',
    klass: AirspaceClass.ctr,
    center: LatLng(45.726, 5.091),
    radiusNm: 8,
    floorFt: 0,
    ceilingFt: 3500,
  );

  group('geometry', () {
    final square = [
      const LatLng(45, 5),
      const LatLng(45, 6),
      const LatLng(44, 6),
      const LatLng(44, 5),
    ];
    test('point in polygon', () {
      expect(Geo.pointInPolygon(const LatLng(44.5, 5.5), square), isTrue);
      expect(Geo.pointInPolygon(const LatLng(46, 5.5), square), isFalse);
    });

    test('circle containment', () {
      expect(ctr.containsHorizontal(const LatLng(45.726, 5.091)), isTrue);
      expect(ctr.containsHorizontal(const LatLng(45.0, 5.091)), isFalse);
    });
  });

  group('vertical profile', () {
    test('flags the airspace segment crossed by the path', () {
      // Start ~13.5 NM south, fly due north at 100 m/s for 20 min.
      final path = AirspaceGeo.sampleTrack(
          const LatLng(45.5, 5.091), 0, 100,
          minutes: 20);
      final boxes = AirspaceGeo.verticalProfile(path, const [ctr]);
      expect(boxes.length, 1);
      // Enters near the southern edge (~5.5 NM) and exits past the far edge.
      expect(boxes.first.xStartNm, inInclusiveRange(3, 8));
      expect(boxes.first.xEndNm, greaterThan(boxes.first.xStartNm + 10));
    });
  });

  group('threat detection', () {
    test('inside when at the centre at a level within the band', () {
      final t = AirspaceGeo.detectThreats(
          const LatLng(45.726, 5.091), 1000, 0, 0, const [ctr]);
      expect(t.length, 1);
      expect(t.first.kind, ThreatKind.inside);
    });

    test('no threat when above the ceiling', () {
      final t = AirspaceGeo.detectThreats(
          const LatLng(45.726, 5.091), 5000, 0, 0, const [ctr]);
      expect(t, isEmpty);
    });

    test('imminent when heading into it within the look-ahead', () {
      final t = AirspaceGeo.detectThreats(
          const LatLng(45.5, 5.091), 1000, 0, 100, const [ctr]);
      expect(t.any((e) => e.kind == ThreatKind.imminent), isTrue);
    });

    test('no threat when heading away', () {
      final t = AirspaceGeo.detectThreats(
          const LatLng(45.5, 5.091), 1000, 180, 100, const [ctr]);
      expect(t, isEmpty);
    });
  });

  test('magnetic conversion applies easterly declination', () {
    const p = LatLng(45.7, 5.0);
    final dec = Magnetic.declinationEast(p);
    expect(Magnetic.trueToMagnetic(90, p), closeTo(90 - dec, 1e-6));
  });
}
