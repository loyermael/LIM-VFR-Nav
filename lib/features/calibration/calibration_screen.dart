import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/geo_math.dart';
import '../../models/chart.dart';
import '../../models/geo_calibration.dart';
import '../../state/chart_state.dart';
import '../import/scale_dialog.dart';

/// Two ways to georeference a raster chart:
///
///  * **Scale mode** (fast, default for printed VFR sheets): the pilot places a
///    single known point; the ground size comes from the printed scale + the
///    raster DPI, and the sheet is assumed north-up (an optional heading covers
///    deliberately-rotated charts). See [AffineGeoref.fromScaleAnchor].
///  * **3-point mode** (general): tap ≥3 features and least-squares-fit a full
///    affine. Needed for scans of unknown scale/rotation. See [AffineGeoref.fit].
///
/// Pixel capture uses [InteractiveViewer] with `constrained: false` and a child
/// sized to the image's exact pixel dimensions, so
/// `TransformationController.toScene()` yields image-pixel coordinates directly.
enum _CalMode { scale, threePoint }

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key, required this.chart});
  final ChartDoc chart;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final TransformationController _tc = TransformationController();
  late ChartDoc _chart = widget.chart;
  late List<CalibrationPoint> _points = List.of(widget.chart.calibration);
  late _CalMode _mode =
      _chart.supportsScaleCalibration ? _CalMode.scale : _CalMode.threePoint;
  double _headingDeg = 0; // chart "up" azimuth for scale mode (0 = north-up)

  bool get _scaleMode => _mode == _CalMode.scale;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _onTapUp(TapUpDetails d) async {
    final scene = _tc.toScene(d.localPosition); // -> image pixel coordinates
    final world = await _askLatLng();
    if (world == null) return;
    setState(() {
      final point = CalibrationPoint(Offset(scene.dx, scene.dy), world);
      if (_scaleMode) {
        _points = [point]; // scale mode needs exactly one anchor
      } else {
        _points.add(point);
      }
    });
  }

  Future<LatLng?> _askLatLng() async {
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    return showDialog<LatLng>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Coordonnées du point'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Latitude (°, décimal)',
                hintText: 'ex : 45.7264',
              ),
            ),
            TextField(
              controller: lngCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Longitude (°, décimal)',
                hintText: 'ex : 5.0908',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final lat = double.tryParse(latCtrl.text.replaceAll(',', '.'));
              final lng = double.tryParse(lngCtrl.text.replaceAll(',', '.'));
              if (lat != null && lng != null) {
                Navigator.pop(ctx, LatLng(lat, lng));
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _editScale() async {
    final chartState = context.read<ChartState>();
    final s = await showScaleDialog(context, current: _chart.scaleDenominator);
    if (s == null) return;
    final updated = _chart.copyWith(scaleDenominator: s);
    await chartState.saveChart(updated);
    if (!mounted) return;
    setState(() {
      _chart = updated;
      if (_chart.supportsScaleCalibration) _mode = _CalMode.scale;
    });
  }

  Future<void> _save() async {
    try {
      final AffineGeoref georef;
      if (_scaleMode) {
        final mpp = _chart.metersPerPixelFromScale!;
        final anchor = _points.single;
        georef = AffineGeoref.fromScaleAnchor(
          anchorPixel: anchor.pixel,
          anchorWorld: anchor.world,
          metersPerPixel: mpp,
          rotationDeg: _headingDeg,
        );
      } else {
        georef = AffineGeoref.fit(_points);
      }
      final updated = _chart.copyWith(calibration: _points, georef: georef);
      final state = context.read<ChartState>();
      await state.saveChart(updated);
      state.setActive(updated);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Calibration invalide : $e')));
      }
    }
  }

  bool get _canSave =>
      _scaleMode ? _points.length == 1 : _points.length >= 3;

  @override
  Widget build(BuildContext context) {
    final mpp = _chart.metersPerPixelFromScale;
    return Scaffold(
      appBar: AppBar(
        title: Text('Calibrer — ${_chart.name}'),
        actions: [
          if (_points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: () => setState(() => _points.removeLast()),
            ),
        ],
      ),
      body: Column(
        children: [
          _modeSelector(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              _scaleMode
                  ? 'Échelle 1 : ${_chart.scaleDenominator}  '
                      '(≈ ${mpp!.toStringAsFixed(0)} m/pixel).  '
                      'Touchez UN repère précis et saisissez sa position.'
                  : 'Points : ${_points.length}/3 min.  '
                      'Zoomez, touchez un repère, saisissez sa position.',
              textAlign: TextAlign.center,
            ),
          ),
          if (_scaleMode) _headingField(),
          Expanded(
            child: GestureDetector(
              onTapUp: _onTapUp,
              child: InteractiveViewer(
                transformationController: _tc,
                constrained: false,
                minScale: 0.1,
                maxScale: 12,
                child: SizedBox(
                  width: _chart.imageWidth,
                  height: _chart.imageHeight,
                  child: Image.file(File(_chart.filePath), fit: BoxFit.fill),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton.icon(
          onPressed: _canSave ? _save : null,
          icon: const Icon(Icons.check),
          label: Text(_saveLabel()),
        ),
      ),
    );
  }

  Widget _modeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<_CalMode>(
              segments: [
                ButtonSegment(
                  value: _CalMode.scale,
                  label: const Text('Échelle (1 pt)'),
                  icon: const Icon(Icons.straighten),
                  enabled: _chart.supportsScaleCalibration,
                ),
                const ButtonSegment(
                  value: _CalMode.threePoint,
                  label: Text('3 points'),
                  icon: Icon(Icons.control_point),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          if (!_chart.supportsScaleCalibration || _scaleMode)
            IconButton(
              tooltip: 'Régler l\'échelle',
              icon: const Icon(Icons.edit_note),
              onPressed: _editScale,
            ),
        ],
      ),
    );
  }

  Widget _headingField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Text('Cap du haut de carte (° vrai) : '),
          SizedBox(
            width: 80,
            child: TextField(
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0 (nord)'),
              onChanged: (v) =>
                  _headingDeg = double.tryParse(v.replaceAll(',', '.')) ?? 0,
            ),
          ),
          const Spacer(),
          const Tooltip(
            message: 'Laissez 0 pour une carte orientée nord (cas habituel).',
            child: Icon(Icons.info_outline, size: 20),
          ),
        ],
      ),
    );
  }

  String _saveLabel() {
    if (_scaleMode) {
      return _canSave
          ? 'Enregistrer (échelle + 1 point)'
          : 'Placez le point de référence';
    }
    return _canSave
        ? 'Enregistrer la calibration'
        : 'Ajoutez ${3 - _points.length} point(s) de plus';
  }
}
