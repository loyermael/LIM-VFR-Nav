import 'package:flutter/material.dart';

import '../../core/notam_language.dart';
import '../../models/notam.dart';

/// Bottom sheet listing NOTAMs (for a tapped zone badge or aerodrome flag) with
/// the jargon distilled into plain-language chips, validity, and the raw text.
void showNotamDetails(BuildContext context, List<Notam> notams) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, controller) => ListView.separated(
        controller: controller,
        padding: const EdgeInsets.all(16),
        itemCount: notams.length,
        separatorBuilder: (_, __) => const Divider(height: 24),
        itemBuilder: (context, i) => _NotamCard(notams[i]),
      ),
    ),
  );
}

class _NotamCard extends StatelessWidget {
  const _NotamCard(this.n);
  final Notam n;

  @override
  Widget build(BuildContext context) {
    final tags = NotamLanguage.tags(n);
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(n.id, style: tt.titleMedium)),
            if (n.aerodromes.isNotEmpty)
              Chip(
                label: Text(n.aerodromes.join(' ')),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [for (final t in tags) _TagChip(t)],
          ),
        const SizedBox(height: 6),
        Text(_validity(n), style: tt.bodySmall),
        if (n.hasSchedule)
          Text('Horaires spécifiques (voir texte)', style: tt.bodySmall),
        const SizedBox(height: 6),
        Text(n.text.isEmpty ? '(pas de texte)' : n.text),
        const SizedBox(height: 6),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Texte brut', style: tt.bodySmall),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(n.raw,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  String _validity(Notam n) {
    String f(DateTime d) {
      final l = d.toLocal();
      String two(int x) => x.toString().padLeft(2, '0');
      return '${two(l.day)}/${two(l.month)} ${two(l.hour)}:${two(l.minute)}';
    }

    final from = f(n.startValid);
    final to = n.permanent || n.endValid == null ? 'PERM' : f(n.endValid!);
    return 'Valide : $from → $to';
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.tag);
  final NotamTag tag;

  @override
  Widget build(BuildContext context) {
    final color = switch (tag.severity) {
      NotamSeverity.high => Colors.red,
      NotamSeverity.medium => Colors.orange,
      NotamSeverity.low => Colors.amber,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(tag.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
