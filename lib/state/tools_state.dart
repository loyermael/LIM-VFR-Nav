import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/measurement.dart';
import '../services/storage_service.dart';

/// Which map interaction is active. Only one at a time: while drawing or
/// measuring, map panning is frozen so the gesture goes to the tool.
enum ActiveTool { none, draw, measure }

/// Where the distance rings are centred.
enum RingCenter { aircraft, fixedPoint }

/// UI/tooling state that isn't navigation data or chart data: night mode,
/// the active tool, distance rings, and the current ruler measurement.
class ToolsState extends ChangeNotifier {
  ToolsState(this._storage) : _nightMode = _storage.nightMode;
  final StorageService _storage;

  ActiveTool _tool = ActiveTool.none;
  ActiveTool get tool => _tool;
  bool get isDrawing => _tool == ActiveTool.draw;
  bool get isMeasuring => _tool == ActiveTool.measure;

  /// True whenever map panning must be suppressed so the gesture reaches a tool.
  bool get mapInteractionFrozen => _tool != ActiveTool.none;

  bool _nightMode;
  bool get nightMode => _nightMode;

  bool _ringsEnabled = false;
  bool get ringsEnabled => _ringsEnabled;
  List<double> _ringRadiiNm = const [2, 5, 10];
  List<double> get ringRadiiNm => _ringRadiiNm;
  RingCenter _ringCenter = RingCenter.aircraft;
  RingCenter get ringCenter => _ringCenter;
  LatLng? _ringFixedCenter;
  LatLng? get ringFixedCenter => _ringFixedCenter;

  Measurement? _measurement;
  Measurement? get measurement => _measurement;

  void setTool(ActiveTool t) {
    // Toggling a tool off returns to plain map navigation.
    _tool = _tool == t ? ActiveTool.none : t;
    if (_tool != ActiveTool.measure) _measurement = null;
    notifyListeners();
  }

  void toggleNightMode() {
    _nightMode = !_nightMode;
    _storage.nightMode = _nightMode;
    notifyListeners();
  }

  void toggleRings() {
    _ringsEnabled = !_ringsEnabled;
    notifyListeners();
  }

  void setRingRadii(List<double> nm) {
    _ringRadiiNm = List.of(nm)..sort();
    notifyListeners();
  }

  void setRingCenter(RingCenter c, {LatLng? fixed}) {
    _ringCenter = c;
    if (c == RingCenter.fixedPoint) _ringFixedCenter = fixed;
    notifyListeners();
  }

  void setMeasurement(LatLng from, LatLng to) {
    _measurement = Measurement(from, to);
    notifyListeners();
  }

  void clearMeasurement() {
    _measurement = null;
    notifyListeners();
  }
}
