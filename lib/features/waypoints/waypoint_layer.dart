import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../models/waypoint.dart';
import '../../state/waypoint_state.dart';

/// Renders the active chart's placemarks as pins. The pin tip sits on the exact
/// geographic point (`alignment: bottomCenter`); tapping a pin opens the editor.
class WaypointLayer extends StatelessWidget {
  const WaypointLayer({super.key, required this.onEdit});

  /// Called when a pin is tapped (to edit/delete it).
  final void Function(Waypoint) onEdit;

  @override
  Widget build(BuildContext context) {
    final items = context.watch<WaypointState>().items;
    if (items.isEmpty) return const SizedBox.shrink();

    return MarkerLayer(
      markers: [
        for (final w in items)
          Marker(
            point: w.position,
            width: 140,
            height: 66,
            alignment: Alignment.bottomCenter, // pin tip on the point
            child: GestureDetector(
              onTap: () => onEdit(w),
              child: _Pin(waypoint: w),
            ),
          ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.waypoint});
  final Waypoint waypoint;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            waypoint.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        Icon(
          Icons.place,
          color: waypoint.color,
          size: 34,
          shadows: const [Shadow(blurRadius: 3, color: Colors.black87)],
        ),
      ],
    );
  }
}
