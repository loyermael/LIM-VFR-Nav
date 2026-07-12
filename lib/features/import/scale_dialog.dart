import 'package:flutter/material.dart';

/// Common VFR/aeronautical chart scales offered as presets.
const Map<String, int> kCommonScales = {
  '1 : 250 000': 250000,
  '1 : 500 000  (OACI France)': 500000,
  '1 : 1 000 000': 1000000,
};

/// Asks the pilot for the printed scale of the chart being imported.
/// Returns the scale denominator (e.g. 500000) or null if cancelled.
Future<int?> showScaleDialog(BuildContext context, {int? current}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => _ScaleDialog(current: current),
  );
}

class _ScaleDialog extends StatefulWidget {
  const _ScaleDialog({this.current});
  final int? current;

  @override
  State<_ScaleDialog> createState() => _ScaleDialogState();
}

class _ScaleDialogState extends State<_ScaleDialog> {
  late int? _selected = widget.current ?? 500000; // OACI default
  final _customCtrl = TextEditingController();
  bool _custom = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Échelle de la carte'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Indiquée sur la carte (ex. « 1 : 500 000 »).'),
          const SizedBox(height: 8),
          for (final entry in kCommonScales.entries)
            RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(entry.key),
              value: entry.value,
              groupValue: _custom ? null : _selected,
              onChanged: (v) => setState(() {
                _custom = false;
                _selected = v;
              }),
            ),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Row(
              children: [
                const Text('1 : '),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _customCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'ex. 200000'),
                    onTap: () => setState(() => _custom = true),
                    onChanged: (_) => setState(() => _custom = true),
                  ),
                ),
              ],
            ),
            value: true,
            groupValue: _custom,
            onChanged: (_) => setState(() => _custom = true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Ignorer'),
        ),
        FilledButton(
          onPressed: () {
            final value = _custom
                ? int.tryParse(_customCtrl.text.replaceAll(RegExp(r'\s'), ''))
                : _selected;
            if (value != null && value > 0) Navigator.pop(context, value);
          },
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
