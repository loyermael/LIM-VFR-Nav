import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../core/notam_language.dart';
import '../../core/units.dart';
import '../../models/notam.dart';
import '../../state/notam_state.dart';

/// Draws the NOTAMs active at the timeline instant on the chart:
///
///  * **Zone NOTAMs** (warning/area scope) → a translucent red/orange disc of
///    the Q-line radius, drawn true-to-ground (`useRadiusInMeter`), with a
///    tappable warning badge at the centre.
///  * **Aerodrome NOTAMs** → an orange/red flag at the field; tapping lists the
///    NOTAMs there in plain language.
///
/// Colour follows [NotamLanguage.severity] (red = high, orange = medium).
class NotamLayer extends StatelessWidget {
  const NotamLayer({super.key, required this.onSelect});

  /// Called with the NOTAM(s) at a tapped badge/flag.
  final void Function(List<Notam>) onSelect;

  static Color _fill(NotamSeverity s) => switch (s) {
        NotamSeverity.high => const Color(0x44E53935),
        NotamSeverity.medium => const Color(0x44FB8C00),
        NotamSeverity.low => const Color(0x44FDD835),
      };
  static Color _edge(NotamSeverity s) => switch (s) {
        NotamSeverity.high => const Color(0xFFE53935),
        NotamSeverity.medium => const Color(0xFFFB8C00),
        NotamSeverity.low => const Color(0xFFF9A825),
      };

  @override
  Widget build(BuildContext context) {
    final st = context.watch<NotamState>();
    if (!st.visible) return const SizedBox.shrink();

    final zones = st.activeZones;

    // Group aerodrome NOTAMs by field (ICAO code, else rounded position) so one
    // flag summarises all NOTAMs there.
    final aeroGroups = <String, List<Notam>>{};
    for (final n in st.activeNow.where((n) => n.isAerodrome)) {
      final key = n.aerodromes.isNotEmpty
          ? n.aerodromes.first
          : '${n.center.latitude.toStringAsFixed(3)},${n.center.longitude.toStringAsFixed(3)}';
      (aeroGroups[key] ??= []).add(n);
    }

    return Stack(children: [
      // Filled discs for zones.
      CircleLayer(
        circles: [
          for (final n in zones)
            CircleMarker(
              point: n.center,
              radius: Units.nmToMeters(n.radiusNm),
              useRadiusInMeter: true,
              color: _fill(NotamLanguage.severity(n)),
              borderColor: _edge(NotamLanguage.severity(n)),
              borderStrokeWidth: 2,
            ),
        ],
      ),
      // Tappable warning badge at each zone centre.
      MarkerLayer(
        markers: [
          for (final n in zones)
            Marker(
              point: n.center,
              width: 34,
              height: 34,
              child: GestureDetector(
                onTap: () => onSelect([n]),
                child: Icon(Icons.warning_amber_rounded,
                    color: _edge(NotamLanguage.severity(n)),
                    size: 30,
                    shadows: const [Shadow(blurRadius: 3, color: Colors.black87)]),
              ),
            ),
        ],
      ),
      // Aerodrome flags.
      MarkerLayer(
        markers: [
          for (final entry in aeroGroups.entries)
            Marker(
              point: entry.value.first.center,
              width: 40,
              height: 40,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () => onSelect(entry.value),
                child: _AeroFlag(notams: entry.value),
              ),
            ),
        ],
      ),
    ]);
  }
}

class _AeroFlag extends StatelessWidget {
  const _AeroFlag({required this.notams});
  final List<Notam> notams;

  @override
  Widget build(BuildContext context) {
    final worst = notams
        .map((n) => NotamLanguage.severity(n))
        .reduce((a, b) => a.index < b.index ? a : b);
    final color = NotamLayer._edge(worst);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.flag, color: color, size: 30, shadows: const [
          Shadow(blurRadius: 3, color: Colors.black87),
        ]),
        if (notams.length > 1)
          Positioned(
            right: -4,
            top: -4,
            child: CircleAvatar(
              radius: 8,
              backgroundColor: Colors.black,
              child: Text('${notams.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
      ],
    );
  }
}
