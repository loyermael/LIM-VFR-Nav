import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../core/units.dart';
import '../../state/nav_state.dart';

/// Prediction horizons for the ground-speed vector (2, 5, 10 and 15 minutes).
const List<int> kVectorMinutes = [2, 5, 10, 15];

/// The dynamic "where will I be" line projected ahead of the aircraft along the
/// current track at the current ground speed. Positions are computed in Lat/Lng
/// (great-circle) so flutter_map handles projection and rotation for us.
class SpeedVectorLayer extends StatelessWidget {
  const SpeedVectorLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final flight = context.watch<NavState>().flight;
    if (!flight.hasFix || !flight.hasValidTrack) {
      return const SizedBox.shrink();
    }
    final origin = flight.position!;
    final color = Theme.of(context).colorScheme.primary;

    // The furthest horizon defines the main line; the shorter ones become ticks.
    final horizons = [
      for (final m in kVectorMinutes)
        Units.destination(
          origin,
          flight.trackDeg,
          flight.groundSpeedMps * m * 60,
        ),
    ];

    return Stack(children: [
      PolylineLayer(polylines: [
        Polyline(
          points: [origin, horizons.last],
          color: color,
          strokeWidth: 3,
        ),
      ]),
      MarkerLayer(
        markers: [
          for (var i = 0; i < kVectorMinutes.length; i++)
            Marker(
              point: horizons[i],
              width: 34,
              height: 20,
              child: _TickLabel(minutes: kVectorMinutes[i], color: color),
            ),
        ],
      ),
    ]);
  }
}

class _TickLabel extends StatelessWidget {
  const _TickLabel({required this.minutes, required this.color});
  final int minutes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        "$minutes'",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// The VFR aircraft symbol at the current GPS position, oriented to the track.
///
/// The marker is kept screen-fixed (`rotate: false`) and we rotate the icon
/// ourselves by `track + mapRotation`, so it points along the real track in
/// North-Up and points straight up in Track-Up (where mapRotation == -track).
class AircraftMarkerLayer extends StatelessWidget {
  const AircraftMarkerLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavState>();
    final flight = nav.flight;
    if (!flight.hasFix) return const SizedBox.shrink();

    final headingDeg = flight.hasValidTrack ? flight.trackDeg : 0.0;
    final iconAngleRad = (headingDeg + nav.mapRotation) * math.pi / 180.0;

    return MarkerLayer(
      markers: [
        Marker(
          point: flight.position!,
          width: 48,
          height: 48,
          rotate: false,
          child: Transform.rotate(
            angle: iconAngleRad,
            child: Icon(
              Icons.navigation, // filled arrow-head, reads as a VFR ship symbol
              size: 44,
              color: Theme.of(context).colorScheme.primary,
              shadows: const [Shadow(blurRadius: 3, color: Colors.black54)],
            ),
          ),
        ),
      ],
    );
  }
}
