import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/notam_source.dart';
import '../../state/notam_state.dart';

/// Ground-side NOTAM management: sync, paste-import, toggle map display, clear.
/// Real SIA/FAA/Eurocontrol endpoints need credentials — wire them into an
/// [HttpNotamSource] and add a button here; the bundled sample works offline.
class NotamScreen extends StatelessWidget {
  const NotamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<NotamState>();
    return Scaffold(
      appBar: AppBar(title: const Text('NOTAM')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Afficher sur la carte'),
            value: st.visible,
            onChanged: st.setVisible,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('${st.count} NOTAM en mémoire (filtrés VFR)'),
            subtitle: Text(st.syncedAt == null
                ? 'Jamais synchronisé'
                : 'Sync : ${st.syncedAt!.toLocal()}'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: st.syncing
                ? null
                : () async {
                    await context.read<NotamState>().sync(SampleNotamSource());
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Synchronisé (exemple Lyon).')));
                    }
                  },
            icon: st.syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_download),
            label: const Text('Synchroniser (exemple)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _importDialog(context),
            icon: const Icon(Icons.paste),
            label: const Text('Importer du texte (coller SIA)'),
          ),
          const SizedBox(height: 8),
          if (st.count > 0)
            TextButton.icon(
              onPressed: () => context.read<NotamState>().clear(),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Effacer'),
            ),
          const SizedBox(height: 16),
          Text(
            'Sync réelle : renseignez une source HTTP (SIA/FAA/Eurocontrol) avec '
            'vos identifiants. Le flux brut est parsé (ligne Q), filtré VFR, et '
            'stocké pour un usage hors-ligne en vol.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _importDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Coller des NOTAM'),
        content: TextField(
          controller: ctrl,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Collez ici le texte brut des NOTAM (lignes Q)…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Importer')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty && context.mounted) {
      await context.read<NotamState>().importRaw(ctrl.text);
    }
  }
}
