import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../core/airspace_geo.dart';
import '../../core/units.dart';
import '../../models/airspace.dart';
import '../../state/airspace_state.dart';
import '../../state/nav_state.dart';

/// Draws airspace footprints (circles + polygons) coloured by class, and
/// highlights in red any controlled/forbidden airspace the aircraft is inside or
/// about to penetrate (from [AirspaceGeo.detectThreats]).
class AirspaceLayer extends StatelessWidget {
  const AirspaceLayer({super.key});

  static Color borderColor(AirspaceClass k) => switch (k) {
        AirspaceClass.ctr => const Color(0xFF1565C0),
        AirspaceClass.tma => const Color(0xFF5E35B1),
        AirspaceClass.prohibited => const Color(0xFFD32F2F),
        AirspaceClass.restricted => const Color(0xFFE64A19),
        AirspaceClass.danger => const Color(0xFFF9A825),
        AirspaceClass.other => const Color(0xFF607D8B),
      };

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AirspaceState>();
    if (!st.showAirspaces) return const SizedBox.shrink();
    final spaces = st.airspaces;

    final flight = context.watch<NavState>().flight;
    final threatened = <String>{};
    if (flight.hasFix) {
      for (final t in AirspaceGeo.detectThreats(
        flight.position!,
        flight.altitudeFeet,
        flight.trackDeg,
        flight.groundSpeedMps,
        spaces,
        trackValid: flight.hasValidTrack,
      )) {
        threatened.add(t.airspace.name);
      }
    }

    Color fill(Airspace a) => (threatened.contains(a.name)
            ? Colors.red
            : borderColor(a.klass))
        .withValues(alpha: threatened.contains(a.name) ? 0.28 : 0.10);
    Color border(Airspace a) =>
        threatened.contains(a.name) ? Colors.red : borderColor(a.klass);
    double width(Airspace a) => threatened.contains(a.name) ? 3 : 1.5;

    return Stack(children: [
      CircleLayer(
        circles: [
          for (final a in spaces.where((a) => a.isCircle))
            CircleMarker(
              point: a.center!,
              radius: Units.nmToMeters(a.radiusNm!),
              useRadiusInMeter: true,
              color: fill(a),
              borderColor: border(a),
              borderStrokeWidth: width(a),
            ),
        ],
      ),
      PolygonLayer(
        polygons: [
          for (final a in spaces.where((a) => !a.isCircle && a.polygon.length >= 3))
            Polygon(
              points: a.polygon,
              color: fill(a),
              borderColor: border(a),
              borderStrokeWidth: width(a),
            ),
        ],
      ),
    ]);
  }
}
