import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../state/direct_to_state.dart';
import '../../state/nav_state.dart';

/// Magenta course line from the aircraft to the Direct-To target, plus a flag at
/// the destination. Drawn in Lat/Lng so flutter_map handles projection/rotation.
class DirectToLayer extends StatelessWidget {
  const DirectToLayer({super.key});

  /// GPS-magenta, the conventional colour for an active course line.
  static const Color courseColor = Color(0xFFD500F9);

  @override
  Widget build(BuildContext context) {
    final target = context.watch<DirectToState>().target;
    final flight = context.watch<NavState>().flight;
    if (target == null || !flight.hasFix) return const SizedBox.shrink();

    return Stack(children: [
      PolylineLayer(polylines: [
        Polyline(
          points: [flight.position!, target],
          color: courseColor,
          strokeWidth: 4,
        ),
      ]),
      MarkerLayer(markers: [
        Marker(
          point: target,
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: const Icon(
            Icons.flag,
            color: courseColor,
            size: 34,
            shadows: [Shadow(blurRadius: 3, color: Colors.black87)],
          ),
        ),
      ]),
    ]);
  }
}
