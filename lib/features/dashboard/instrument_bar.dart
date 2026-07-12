import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/units.dart';
import '../../state/nav_state.dart';

/// The discreet in-flight instrument strip overlaid on the map:
/// GS (kt) · TRK (°) · ALT (ft), recomputed continuously from GPS.
///
/// Shows a clear placeholder ("--") until a valid fix/track is available, so a
/// missing value is never mistaken for a real reading.
class InstrumentBar extends StatelessWidget {
  const InstrumentBar({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavState>();
    final flight = nav.flight;
    final wind = nav.wind;
    final degraded = !flight.hasFix || flight.accuracyMeters > 50;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: degraded
              ? Border.all(color: Colors.orangeAccent, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Field(
              label: 'GS',
              value: flight.hasFix
                  ? flight.groundSpeedKts.toStringAsFixed(0)
                  : '--',
              unit: 'kt',
            ),
            const _Divider(),
            _Field(
              label: 'TRK',
              value: flight.hasValidTrack
                  ? Units.formatBearing(flight.trackDeg)
                  : '--',
              unit: '°',
            ),
            const _Divider(),
            _Field(
              label: 'ALT',
              value: flight.hasFix
                  ? flight.altitudeFeet.toStringAsFixed(0)
                  : '--',
              unit: 'ft',
            ),
            if (wind != null) ...[
              const _Divider(),
              _Field(
                label: 'WIND',
                value: '${Units.formatBearing(wind.fromDeg)}/'
                    '${wind.speedKts.toStringAsFixed(0)}',
                unit: 'kt',
              ),
            ],
            if (degraded) ...[
              const SizedBox(width: 10),
              const Icon(Icons.gps_off, color: Colors.orangeAccent, size: 22),
            ],
          ],
        ),
      ),
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
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 2),
            Text(unit,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white24,
      );
}
