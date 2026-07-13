import 'package:latlong2/latlong.dart';

import '../models/airspace.dart';

/// Bundled **sample** airspaces around Lyon so the vertical profile, map layer
/// and penetration alerts work fully offline out of the box.
///
/// ⚠️ Illustrative geometry/limits — NOT for real navigation. Replace with an
/// OpenAIP/SIA import (see the P3 epic) before operational use.
class SampleAirspaceData {
  static List<Airspace> all() => const [
        Airspace(
          name: 'CTR LYON ST-EXUPÉRY',
          klass: AirspaceClass.ctr,
          center: LatLng(45.726, 5.091),
          radiusNm: 8,
          floorFt: 0,
          ceilingFt: 3500,
        ),
        Airspace(
          name: 'TMA LYON',
          klass: AirspaceClass.tma,
          center: LatLng(45.70, 5.00),
          radiusNm: 25,
          floorFt: 3500,
          ceilingFt: 11500,
        ),
        Airspace(
          name: 'P LYON BUGEY (centrale)',
          klass: AirspaceClass.prohibited,
          center: LatLng(45.798, 5.271),
          radiusNm: 1.6,
          floorFt: 0,
          ceilingFt: 3300,
        ),
        Airspace(
          name: 'R VERCORS (militaire)',
          klass: AirspaceClass.restricted,
          polygon: [
            LatLng(45.10, 5.35),
            LatLng(45.10, 5.75),
            LatLng(44.85, 5.75),
            LatLng(44.85, 5.35),
          ],
          floorFt: 1000,
          ceilingFt: 9500,
        ),
      ];
}
