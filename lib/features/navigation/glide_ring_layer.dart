import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../core/glide_math.dart';
import '../../core/units.dart';
import '../../state/aircraft_state.dart';
import '../../state/nav_state.dart';
import '../../state/tools_state.dart';

/// The wind-corrected glide-range footprint: the area still reachable in a
/// straight glide from the current position, down to the configured arrival
/// altitude. Uses the active aircraft's glide ratio (and TAS for the wind
/// correction). Silently hidden when it can't be computed (no fix, no glide
/// ratio set, or already below arrival altitude).
class GlideRingLayer extends StatelessWidget {
  const GlideRingLayer({super.key});

  static const Color _fill = Color(0x2600C853); // translucent green
  static const Color _edge = Color(0xFF00C853);

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<ToolsState>();
    if (!tools.glideRingEnabled) return const SizedBox.shrink();

    final flight = context.watch<NavState>().flight;
    final aircraft = context.watch<AircraftState>().active;
    final ratio = aircraft?.glideRatio;
    if (!flight.hasFix || ratio == null) return const SizedBox.shrink();

    final altAglFt = flight.altitudeFeet - tools.arrivalAltFt;
    if (altAglFt <= 0) return const SizedBox.shrink();

    // Prefer the auto (circling) wind estimate; fall back to manual values.
    final estimate = context.watch<NavState>().wind;
    final useAuto = tools.autoWind && estimate != null;
    final windFromDeg = useAuto ? estimate.fromDeg : tools.windFromDeg;
    final windKts = useAuto ? estimate.speedKts : tools.windKts;

    // TAS drives the wind stretch; use the profile's, else the estimate's.
    final tasKts = aircraft?.cruiseTasKts ?? (useAuto ? estimate.tasKts : null);

    final points = glideRangePolygon(
      center: flight.position!,
      altAglMeters: Units.feetToMeters(altAglFt),
      glideRatio: ratio,
      tasMps: tasKts != null ? Units.knotsToMps(tasKts) : null,
      windToDeg: Units.normalizeBearing(windFromDeg + 180),
      windMps: Units.knotsToMps(windKts),
    );

    return PolygonLayer(
      polygons: [
        Polygon(
          points: points,
          color: _fill,
          borderColor: _edge,
          borderStrokeWidth: 2,
        ),
      ],
    );
  }
}
