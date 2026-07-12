import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/units.dart';
import '../../state/nav_state.dart';
import '../../state/tools_state.dart';

/// Concentric range rings (2 / 5 / 10 NM by default) centred either on the
/// aircraft or on a pilot-chosen fixed point. Radii are given in metres with
/// `useRadiusInMeter`, so the rings stay true-to-ground at every zoom.
class DistanceRingsLayer extends StatelessWidget {
  const DistanceRingsLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<ToolsState>();
    if (!tools.ringsEnabled) return const SizedBox.shrink();

    final LatLng? center = switch (tools.ringCenter) {
      RingCenter.aircraft => context.watch<NavState>().flight.position,
      RingCenter.fixedPoint => tools.ringFixedCenter,
    };
    if (center == null) return const SizedBox.shrink();

    final ringColor =
        Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.9);

    return Stack(children: [
      CircleLayer(
        circles: [
          for (final nm in tools.ringRadiiNm)
            CircleMarker(
              point: center,
              radius: Units.nmToMeters(nm),
              useRadiusInMeter: true,
              color: Colors.transparent,
              borderColor: ringColor,
              borderStrokeWidth: 1.5,
            ),
        ],
      ),
      MarkerLayer(
        markers: [
          for (final nm in tools.ringRadiiNm)
            Marker(
              // Label sits on the ring's north edge.
              point: Units.destination(center, 0, Units.nmToMeters(nm)),
              width: 44,
              height: 18,
              child: _RingLabel(nm: nm, color: ringColor),
            ),
        ],
      ),
    ]);
  }
}

class _RingLabel extends StatelessWidget {
  const _RingLabel({required this.nm, required this.color});
  final double nm;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        color: Colors.black54,
        child: Text(
          '${nm.toStringAsFixed(nm.truncateToDouble() == nm ? 0 : 1)} NM',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
