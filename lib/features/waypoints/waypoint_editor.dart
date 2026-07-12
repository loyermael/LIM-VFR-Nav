import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/waypoint.dart';
import '../../state/waypoint_state.dart';

/// Colours offered for placemarks.
class WaypointColors {
  WaypointColors._();
  static const List<int> palette = [
    0xFFE53935, // red
    0xFF1E88E5, // blue
    0xFFFDD835, // yellow
    0xFF43A047, // green
    0xFF8E24AA, // purple
    0xFFFFFFFF, // white
  ];
}

/// Add (when [at] is given) or edit (when [existing] is given) a placemark.
/// Applies changes directly to [WaypointState].
Future<void> showWaypointEditor(
  BuildContext context, {
  LatLng? at,
  Waypoint? existing,
}) {
  assert(at != null || existing != null);
  return showDialog<void>(
    context: context,
    builder: (_) => _WaypointEditor(at: at, existing: existing),
  );
}

class _WaypointEditor extends StatefulWidget {
  const _WaypointEditor({this.at, this.existing});
  final LatLng? at;
  final Waypoint? existing;

  @override
  State<_WaypointEditor> createState() => _WaypointEditorState();
}

class _WaypointEditorState extends State<_WaypointEditor> {
  late final TextEditingController _name;
  late final TextEditingController _note;
  late int _color;

  bool get _isEdit => widget.existing != null;
  LatLng get _pos => widget.existing?.position ?? widget.at!;

  @override
  void initState() {
    super.initState();
    final state = context.read<WaypointState>();
    _name = TextEditingController(
        text: widget.existing?.name ?? 'WPT ${state.count + 1}');
    _note = TextEditingController(text: widget.existing?.note ?? '');
    _color = widget.existing?.colorValue ?? WaypointColors.palette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final state = context.read<WaypointState>();
    final wp = (widget.existing ??
            Waypoint(
              id: WaypointState.newId(),
              name: '',
              position: _pos,
              colorValue: _color,
            ))
        .copyWith(
      name: _name.text.trim().isEmpty ? 'WPT' : _name.text.trim(),
      colorValue: _color,
      note: _note.text.trim(),
    );
    _isEdit ? state.update(wp) : state.add(wp);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Modifier le point' : 'Nouveau point'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: !_isEdit,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          const SizedBox(height: 8),
          Text(
            '${_pos.latitude.toStringAsFixed(5)}, '
            '${_pos.longitude.toStringAsFixed(5)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              for (final c in WaypointColors.palette)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == c ? Colors.black : Colors.black26,
                        width: _color == c ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Note (optionnel)'),
          ),
        ],
      ),
      actions: [
        if (_isEdit)
          TextButton(
            onPressed: () {
              context.read<WaypointState>().remove(widget.existing!.id);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: _save,
          child: Text(_isEdit ? 'Enregistrer' : 'Ajouter'),
        ),
      ],
    );
  }
}

/// Bottom sheet listing the chart's placemarks. [onSelect] is called to centre
/// the map on a chosen point.
void showWaypointList(
  BuildContext context, {
  required void Function(Waypoint) onSelect,
}) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => Consumer<WaypointState>(
      // Use the outer [context] (not the sheet's, which is torn down on pop)
      // for navigation and reopening the editor.
      builder: (_, state, __) {
        if (state.items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Aucun point. Appui long sur la carte pour en poser un.'),
          );
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final w in state.items)
                ListTile(
                  leading: Icon(Icons.place, color: w.color),
                  title: Text(w.name),
                  subtitle: Text(
                    '${w.position.latitude.toStringAsFixed(4)}, '
                    '${w.position.longitude.toStringAsFixed(4)}'
                    '${w.note.isNotEmpty ? '  ·  ${w.note}' : ''}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.of(context).pop();
                      showWaypointEditor(context, existing: w);
                    },
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelect(w);
                  },
                ),
            ],
          ),
        );
      },
    ),
  );
}
