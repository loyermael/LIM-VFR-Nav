import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/aircraft_profile.dart';
import '../../state/aircraft_state.dart';

/// Manage aircraft profiles: create/edit/delete and pick the active one.
class AircraftScreen extends StatelessWidget {
  const AircraftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AircraftState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profils avion')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau'),
      ),
      body: state.profiles.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun profil. Ajoutez votre planeur ou avion '
                  '(TAS, finesse, conso) pour alimenter les calculs.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RadioGroup<String>(
              groupValue: state.active?.id,
              onChanged: (id) {
                if (id != null) context.read<AircraftState>().setActive(id);
              },
              child: ListView(
                children: [
                  for (final p in state.profiles)
                    RadioListTile<String>(
                      value: p.id,
                      title: Text(p.name),
                      subtitle: Text(_summary(p)),
                      secondary: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _edit(context, p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                context.read<AircraftState>().remove(p.id),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  static String _summary(AircraftProfile p) {
    final parts = <String>[
      if (p.cruiseTasKts != null) 'TAS ${p.cruiseTasKts!.toStringAsFixed(0)} kt',
      if (p.glideRatio != null) 'finesse ${p.glideRatio!.toStringAsFixed(0)}',
      if (p.fuelBurnLph != null) '${p.fuelBurnLph!.toStringAsFixed(1)} L/h',
    ];
    return parts.isEmpty ? '—' : parts.join('  ·  ');
  }

  static void _edit(BuildContext context, AircraftProfile? existing) {
    showDialog<void>(
      context: context,
      builder: (_) => _ProfileDialog(existing: existing),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({this.existing});
  final AircraftProfile? existing;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _tas = TextEditingController(
      text: widget.existing?.cruiseTasKts?.toStringAsFixed(0) ?? '');
  late final TextEditingController _glide = TextEditingController(
      text: widget.existing?.glideRatio?.toStringAsFixed(0) ?? '');
  late final TextEditingController _fuel = TextEditingController(
      text: widget.existing?.fuelBurnLph?.toString() ?? '');

  @override
  void dispose() {
    _name.dispose();
    _tas.dispose();
    _glide.dispose();
    _fuel.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final base = widget.existing ??
        AircraftProfile(id: AircraftState.newId(), name: name);
    final p = base.copyWith(
      name: name,
      cruiseTasKts: _num(_tas),
      glideRatio: _num(_glide),
      fuelBurnLph: _num(_fuel),
    );
    context.read<AircraftState>().addOrUpdate(p);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nouveau profil' : 'Modifier le profil'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Nom / immatriculation', hintText: 'ex : LS4 F-CGxx'),
            ),
            _numField(_tas, 'TAS de croisière', 'kt'),
            _numField(_glide, 'Finesse (glide ratio)', ''),
            _numField(_fuel, 'Consommation', 'L/h'),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler')),
        FilledButton(onPressed: _save, child: const Text('Enregistrer')),
      ],
    );
  }

  Widget _numField(TextEditingController c, String label, String unit) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit.isEmpty ? null : unit,
        hintText: 'optionnel',
      ),
    );
  }
}
