import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/units.dart';
import '../../state/direct_to_state.dart';
import '../../state/nav_state.dart';
import 'direct_to_layer.dart';

/// Compact banner shown while a Direct-To leg is active: destination name,
/// distance (NM), desired track DTK (°), estimated time en route, and a
/// turn cue (how far and which way to turn onto the course). All derived live
/// from the GPS [FlightState].
class DirectToPanel extends StatelessWidget {
  const DirectToPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final dt = context.watch<DirectToState>();
    if (!dt.isActive) return const SizedBox.shrink();
    final flight = context.watch<NavState>().flight;

    String dist = '--', dtk = '--', ete = '--';
    if (flight.hasFix) {
      final m = Units.distanceMeters(flight.position!, dt.target!);
      dist = Units.metersToNm(m).toStringAsFixed(1);
      dtk = Units.formatBearing(Units.bearingDeg(flight.position!, dt.target!));
      if (flight.groundSpeedMps > 0.5) {
        ete = _fmtEte(m / flight.groundSpeedMps);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DirectToLayer.courseColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.navigation, color: DirectToLayer.courseColor, size: 20),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              dt.name ?? 'Direct-To',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const _Sep(),
          _Field(label: 'DIST', value: dist, unit: 'NM'),
          const _Sep(),
          _Field(label: 'DTK', value: dtk, unit: '°'),
          const _Sep(),
          _Field(label: 'ETE', value: ete, unit: ''),
          if (flight.hasFix && flight.hasValidTrack) ...[
            const SizedBox(width: 8),
            _TurnCue(
              dtk: Units.bearingDeg(flight.position!, dt.target!),
              track: flight.trackDeg,
            ),
          ],
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => context.read<DirectToState>().clear(),
          ),
        ],
      ),
    );
  }

  static String _fmtEte(double seconds) {
    if (!seconds.isFinite || seconds > 24 * 3600) return '--';
    final s = seconds.round();
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }
}

/// Arrow + degrees showing which way and how far to turn onto the course.
class _TurnCue extends StatelessWidget {
  const _TurnCue({required this.dtk, required this.track});
  final double dtk;
  final double track;

  @override
  Widget build(BuildContext context) {
    final rel = Units.normalizeBearing(dtk - track);
    final left = rel > 180;
    final deg = left ? (360 - rel) : rel;
    if (deg < 1) {
      return const Text('ON', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(left ? Icons.turn_left : Icons.turn_right,
            color: Colors.amberAccent, size: 22),
        Text('${deg.round()}°',
            style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                )),
            if (unit.isNotEmpty)
              Text(unit, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 8), color: Colors.white24);
}
