import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/annotation.dart';
import '../services/storage_service.dart';

/// The scratchpad: freehand vector strokes anchored to the chart, plus the pen
/// settings shown in the drawing toolbar. Strokes are persisted per chart so a
/// pilot's route markings survive an app restart.
class AnnotationState extends ChangeNotifier {
  AnnotationState(this._storage);
  final StorageService _storage;

  String? _chartId;
  final List<Stroke> _strokes = [];
  Stroke? _inProgress;

  int _penColor = PenColors.red;
  double _penWidth = 5.0;

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  Stroke? get inProgress => _inProgress;
  int get penColor => _penColor;
  double get penWidth => _penWidth;
  bool get canUndo => _strokes.isNotEmpty;

  /// Switch the strokes to those belonging to [chartId], loading from disk.
  Future<void> loadForChart(String chartId) async {
    _chartId = chartId;
    _strokes
      ..clear()
      ..addAll(await _storage.loadStrokes(chartId));
    _inProgress = null;
    notifyListeners();
  }

  void setColor(int argb) {
    _penColor = argb;
    notifyListeners();
  }

  void setWidth(double px) {
    _penWidth = px;
    notifyListeners();
  }

  // --- stroke lifecycle (driven by the drawing gesture) --------------------

  void beginStroke(LatLng first) {
    _inProgress = Stroke(
      points: [first],
      colorValue: _penColor,
      widthPx: _penWidth,
    );
    notifyListeners();
  }

  void extendStroke(LatLng point) {
    final s = _inProgress;
    if (s == null) return;
    _inProgress = Stroke(
      points: [...s.points, point],
      colorValue: s.colorValue,
      widthPx: s.widthPx,
    );
    notifyListeners();
  }

  void endStroke() {
    final s = _inProgress;
    if (s != null && s.points.length > 1) {
      _strokes.add(s);
      _persist();
    }
    _inProgress = null;
    notifyListeners();
  }

  void undo() {
    if (_strokes.isEmpty) return;
    _strokes.removeLast();
    _persist();
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    _persist();
    notifyListeners();
  }

  void _persist() {
    final id = _chartId;
    if (id != null) _storage.saveStrokes(id, _strokes);
  }
}
