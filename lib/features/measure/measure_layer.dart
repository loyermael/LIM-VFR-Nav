import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/magnetic.dart';
import '../../core/units.dart';
import '../../state/nav_state.dart';
import '../../state/tools_state.dart';

/// Draws the virtual ruler: a line between the two measured points with a badge
/// showing distance (NM) and TRUE bearing at the midpoint.
class MeasureLayer extends StatelessWidget {
  const MeasureLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<ToolsState>().measurement;
    if (m == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final mid = LatLng(
      (m.from.latitude + m.to.latitude) / 2,
      (m.from.longitude + m.to.longitude) / 2,
    );

    // NM · magnetic course · flight time (from current GS, else 90 kt cruise).
    final flight = context.watch<NavState>().flight;
    final gs = flight.groundSpeedMps > Units.knotsToMps(5)
        ? flight.groundSpeedMps
        : Units.knotsToMps(90);
    final eteSec = Units.nmToMeters(m.distanceNm) / gs;
    final mag = Magnetic.trueToMagnetic(m.bearingDeg, m.to);
    String two(int x) => x.toString().padLeft(2, '0');
    final ete = '${two(eteSec ~/ 60)}:${two((eteSec % 60).round())}';
    final label =
        '${m.distanceNm.toStringAsFixed(1)} NM · ${Units.formatBearing(mag)}°M · $ete';

    return Stack(children: [
      PolylineLayer(polylines: [
        Polyline(
          points: [m.from, m.to],
          color: cs.secondary,
          strokeWidth: 3,
          pattern: const StrokePattern.dotted(),
        ),
      ]),
      MarkerLayer(markers: [
        for (final p in [m.from, m.to])
          Marker(
            point: p,
            width: 16,
            height: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        Marker(
          point: mid,
          width: 220,
          height: 32,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: cs.onSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ]),
    ]);
  }
}

/// Captures the two ruler endpoints while the Measure tool is active.
///
/// UX: tap once to drop the start point, tap again for the end — the line and
/// read-out appear instantly. A third tap starts a fresh measurement. (This is
/// more reliable in a bumpy cockpit than a two-finger gesture, while giving the
/// same "tap-to-measure" result described in the spec.)
class MeasureGestureLayer extends StatefulWidget {
  const MeasureGestureLayer({super.key});

  @override
  State<MeasureGestureLayer> createState() => _MeasureGestureLayerState();
}

class _MeasureGestureLayerState extends State<MeasureGestureLayer> {
  LatLng? _first;

  @override
  Widget build(BuildContext context) {
    final measuring = context.select<ToolsState, bool>((t) => t.isMeasuring);
    if (!measuring) {
      _first = null;
      return const SizedBox.shrink();
    }
    final camera = MapCamera.of(context);
    final tools = context.read<ToolsState>();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        final p = camera.offsetToCrs(d.localPosition);
        if (_first == null) {
          setState(() => _first = p);
          tools.clearMeasurement();
        } else {
          tools.setMeasurement(_first!, p);
          _first = null;
        }
      },
      child: const SizedBox.expand(),
    );
  }
}
