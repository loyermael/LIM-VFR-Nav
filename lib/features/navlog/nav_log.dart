import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/magnetic.dart';
import '../../core/units.dart';
import '../../models/waypoint.dart';
import '../../state/nav_state.dart';
import '../../state/waypoint_state.dart';

/// Live nav log: treats the placemark list as the route (in order) and, from the
/// current GPS position, computes for each point the remaining distance, the
/// magnetic heading of the leg into it, and a continuously-recomputed ETA from
/// ground speed (default 90 kt if stationary).
void showNavLog(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.6,
      child: _NavLogBody(),
    ),
  );
}

class _NavLogBody extends StatelessWidget {
  const _NavLogBody();

  static const double _defaultCruiseKt = 90;

  @override
  Widget build(BuildContext context) {
    final flight = context.watch<NavState>().flight;
    final points = context.watch<WaypointState>().items;

    if (points.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Aucun point. Posez des marqueurs : ils forment la route.'),
        ),
      );
    }

    final origin = flight.position;
    final gsMps = flight.groundSpeedMps > Units.knotsToMps(5)
        ? flight.groundSpeedMps
        : Units.knotsToMps(_defaultCruiseKt);
    final now = DateTime.now();

    // Cumulative distance from the aircraft through the ordered points.
    var cumM = 0.0;
    LatLng? prev = origin;
    final rows = <Widget>[];
    for (final w in points) {
      double? legM;
      double? magHdg;
      if (prev != null) {
        legM = Units.distanceMeters(prev, w.position);
        cumM += legM;
        magHdg = Magnetic.trueToMagnetic(
            Units.bearingDeg(prev, w.position), w.position);
      }
      final eta = origin != null ? now.add(Duration(seconds: (cumM / gsMps).round())) : null;
      rows.add(_LegRow(
        wp: w,
        distToGoNm: origin != null ? Units.metersToNm(cumM) : null,
        magHeading: magHdg,
        eta: eta,
      ));
      prev = w.position;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('Log de navigation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const _HeaderRow(),
        const Divider(height: 1),
        Expanded(child: ListView(children: rows)),
        if (origin == null)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Sans fix GPS : distances/ETA depuis le 1er point.',
                style: TextStyle(fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();
  @override
  Widget build(BuildContext context) {
    const s = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        Expanded(flex: 3, child: Text('Point', style: s)),
        Expanded(flex: 2, child: Text('Dist', style: s)),
        Expanded(flex: 2, child: Text('Cap M', style: s)),
        Expanded(flex: 2, child: Text('ETA', style: s)),
      ]),
    );
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({
    required this.wp,
    required this.distToGoNm,
    required this.magHeading,
    required this.eta,
  });
  final Waypoint wp;
  final double? distToGoNm;
  final double? magHeading;
  final DateTime? eta;

  @override
  Widget build(BuildContext context) {
    String two(int x) => x.toString().padLeft(2, '0');
    final etaStr =
        eta == null ? '--' : '${two(eta!.toLocal().hour)}:${two(eta!.toLocal().minute)}';
    const val = TextStyle(fontSize: 16, fontFeatures: [FontFeature.tabularFigures()]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Expanded(
            flex: 3,
            child: Row(children: [
              Icon(Icons.place, size: 16, color: wp.color),
              const SizedBox(width: 4),
              Expanded(child: Text(wp.name, overflow: TextOverflow.ellipsis)),
            ])),
        Expanded(
            flex: 2,
            child: Text(
                distToGoNm == null ? '--' : distToGoNm!.toStringAsFixed(1),
                style: val)),
        Expanded(
            flex: 2,
            child: Text(magHeading == null ? '--' : '${Units.formatBearing(magHeading!)}°',
                style: val)),
        Expanded(flex: 2, child: Text(etaStr, style: val)),
      ]),
    );
  }
}
