import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/aircraft_state.dart';
import '../../state/nav_state.dart';
import '../../state/tools_state.dart';
import '../aircraft/aircraft_screen.dart';

/// Bottom sheet controlling the glide-range ring: enable it, and set the
/// arrival altitude and (manual) wind used for the computation.
void showGlideSettings(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _GlideSettings(),
  );
}

class _GlideSettings extends StatefulWidget {
  const _GlideSettings();

  @override
  State<_GlideSettings> createState() => _GlideSettingsState();
}

class _GlideSettingsState extends State<_GlideSettings> {
  late final TextEditingController _arr;
  late final TextEditingController _windDir;
  late final TextEditingController _windKt;

  @override
  void initState() {
    super.initState();
    final t = context.read<ToolsState>();
    _arr = TextEditingController(text: t.arrivalAltFt.toStringAsFixed(0));
    _windDir = TextEditingController(text: t.windFromDeg.toStringAsFixed(0));
    _windKt = TextEditingController(text: t.windKts.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _arr.dispose();
    _windDir.dispose();
    _windKt.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Widget _autoWindTile(BuildContext context, ToolsState tools) {
    final wind = context.watch<NavState>().wind;
    final subtitle = wind == null
        ? 'En attente d\'une spirale complète…'
        : 'Estimé : ${wind.fromDeg.toStringAsFixed(0)}° / '
            '${wind.speedKts.toStringAsFixed(0)} kt  '
            '(TAS ≈ ${wind.tasKts.toStringAsFixed(0)} kt)';
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Vent automatique (en spirale)'),
      subtitle: Text(subtitle),
      value: tools.autoWind,
      onChanged: tools.setAutoWind,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<ToolsState>();
    final ratio = context.watch<AircraftState>().active?.glideRatio;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Anneau de plané'),
            subtitle: Text(ratio != null
                ? 'Finesse active : ${ratio.toStringAsFixed(0)}'
                : 'Aucune finesse — définissez-la dans un profil avion'),
            value: tools.glideRingEnabled,
            onChanged: (v) {
              if (v == tools.glideRingEnabled) return;
              tools.toggleGlideRing();
            },
          ),
          if (ratio == null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.flight),
                label: const Text('Ouvrir les profils avion'),
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(MaterialPageRoute(
                      builder: (_) => const AircraftScreen()));
                },
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _arr,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Altitude d\'arrivée',
              suffixText: 'ft',
              helperText: 'Niveau visé (terrain + marge). 0 = niveau mer.',
            ),
            onChanged: (_) =>
                tools.setGlideParams(arrivalAltFt: _num(_arr) ?? 0),
          ),
          const Divider(),
          _autoWindTile(context, tools),
          const SizedBox(height: 4),
          // Manual wind — used when auto is off or no estimate is available yet.
          Opacity(
            opacity: tools.autoWind ? 0.5 : 1,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _windDir,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Vent du (manuel)', suffixText: '°'),
                    onChanged: (_) =>
                        tools.setGlideParams(windFromDeg: _num(_windDir) ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _windKt,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Vent', suffixText: 'kt'),
                    onChanged: (_) =>
                        tools.setGlideParams(windKts: _num(_windKt) ?? 0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
