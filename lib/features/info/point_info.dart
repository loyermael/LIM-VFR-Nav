import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/airfield.dart';
import '../../models/airspace.dart';
import '../../services/airfield_data.dart';
import '../../state/airspace_state.dart';
import '../../state/direct_to_state.dart';
import '../waypoints/waypoint_editor.dart';

/// Long-press context menu on the map: the pilot picks Infos / drop a point /
/// Direct-To. "Infos" opens the smart-tap popup (nearest field's frequencies +
/// elevation, and the airspaces overhead) in large, cockpit-legible type.
void showPointContextMenu(BuildContext context, LatLng at) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Infos du point'),
            onTap: () {
              Navigator.pop(sheetCtx);
              showPointInfo(context, at);
            },
          ),
          ListTile(
            leading: const Icon(Icons.push_pin_outlined),
            title: const Text('Poser un point ici'),
            onTap: () {
              Navigator.pop(sheetCtx);
              showWaypointEditor(context, at: at);
            },
          ),
          ListTile(
            leading: const Icon(Icons.navigation),
            title: const Text('Direct-To ici'),
            onTap: () {
              context.read<DirectToState>().setTarget(at, name: 'Point');
              Navigator.pop(sheetCtx);
            },
          ),
        ],
      ),
    ),
  );
}

/// Smart-tap popup: field frequencies + elevation, and airspaces at [at].
void showPointInfo(BuildContext context, LatLng at) {
  final field = AirfieldData.nearest(at, maxNm: 6);
  final spaces = context
      .read<AirspaceState>()
      .airspaces
      .where((a) => a.containsHorizontal(at))
      .toList();

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (field != null) _FieldInfo(field) else _NoField(at),
            if (spaces.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Espaces à la verticale',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              for (final a in spaces) _AirspaceRow(a),
            ],
          ],
        ),
      ),
    ),
  );
}

class _FieldInfo extends StatelessWidget {
  const _FieldInfo(this.f);
  final Airfield f;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${f.name}  ',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Chip(label: Text(f.icao)),
          ],
        ),
        Text('Alt. ${f.elevationFt.round()} ft AMSL',
            style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        // Frequencies: high contrast, large (≥16sp) for turbulence legibility.
        for (final fr in f.freqs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(fr.type,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                SelectableText(
                  fr.mhz,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NoField extends StatelessWidget {
  const _NoField(this.at);
  final LatLng at;
  @override
  Widget build(BuildContext context) => Text(
        'Aucun terrain à proximité.\n'
        '${at.latitude.toStringAsFixed(4)}, ${at.longitude.toStringAsFixed(4)}',
        style: const TextStyle(fontSize: 16),
      );
}

class _AirspaceRow extends StatelessWidget {
  const _AirspaceRow(this.a);
  final Airspace a;
  @override
  Widget build(BuildContext context) {
    String fl(double ft) => ft <= 0 ? 'SFC' : '${ft.round()} ft';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        '${a.name} — ${fl(a.floorFt)} → ${fl(a.ceilingFt)}',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
