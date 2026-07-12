import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chart.dart';
import '../../services/chart_repository.dart';
import '../../state/chart_state.dart';
import '../calibration/calibration_screen.dart';
import 'scale_dialog.dart';

/// Chart library: import new charts, pick the active one, calibrate or delete.
class ChartImportScreen extends StatefulWidget {
  const ChartImportScreen({super.key});

  @override
  State<ChartImportScreen> createState() => _ChartImportScreenState();
}

class _ChartImportScreenState extends State<ChartImportScreen> {
  bool _busy = false;

  Future<void> _import() async {
    // Capture providers up-front so we never touch `context` across an await.
    final repo = context.read<ChartRepository>();
    final chartState = context.read<ChartState>();

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'mbtiles'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    // A chart PDF is often a multi-page booklet — let the pilot pick the page
    // that actually holds the map before we rasterise it.
    var pdfPage = 1;
    if (path.toLowerCase().endsWith('.pdf')) {
      final count = await repo.pdfPageCount(path);
      if (!mounted) return;
      if (count > 1) {
        final chosen = await _askPage(count);
        if (chosen == null) return; // cancelled
        pdfPage = chosen;
      }
    }

    setState(() => _busy = true);
    try {
      var chart = await repo.importFile(path, pdfPage: pdfPage);
      if (!mounted) return;
      // Raster charts must be calibrated before they can be displayed. For a
      // printed VFR sheet we first ask its scale — that unlocks the fast
      // single-point (north-up) calibration.
      if (chart.kind == ChartKind.rasterOverlay) {
        final scale = await showScaleDialog(context);
        if (scale != null) {
          chart = chart.copyWith(scaleDenominator: scale);
          await repo.update(chart);
        }
        await chartState.refresh();
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CalibrationScreen(chart: chart),
        ));
      } else {
        await chartState.refresh();
        if (!mounted) return;
        chartState.setActive(chart);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import échoué : $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<int?> _askPage(int count) {
    final ctrl = TextEditingController(text: '1');
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Page de la carte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ce PDF a $count pages. Laquelle contient la carte ?'),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(labelText: 'Page (1–$count)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text);
              if (n != null && n >= 1 && n <= count) Navigator.pop(ctx, n);
            },
            child: const Text('Importer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final charts = context.watch<ChartState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cartes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _import,
        icon: _busy
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.file_open),
        label: const Text('Importer'),
      ),
      body: charts.charts.isEmpty
          ? const Center(child: Text('Aucune carte. Importez un PDF, une image ou un .mbtiles.'))
          : ListView.separated(
              itemCount: charts.charts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = charts.charts[i];
                final active = charts.active?.id == c.id;
                return ListTile(
                  leading: Icon(
                    c.kind == ChartKind.mbtiles ? Icons.grid_on : Icons.image,
                    color: active ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(c.name),
                  subtitle: Text(
                    c.isCalibrated ? 'Prête' : 'À calibrer',
                    style: TextStyle(
                      color: c.isCalibrated ? null : Colors.orange,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.kind == ChartKind.rasterOverlay)
                        IconButton(
                          icon: const Icon(Icons.tune),
                          tooltip: 'Calibrer',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CalibrationScreen(chart: c),
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => context.read<ChartState>().deleteChart(c),
                      ),
                    ],
                  ),
                  selected: active,
                  onTap: c.isCalibrated
                      ? () {
                          context.read<ChartState>().setActive(c);
                          Navigator.of(context).pop();
                        }
                      : null,
                );
              },
            ),
    );
  }
}
