import 'package:flutter/foundation.dart';

import '../models/waypoint.dart';
import '../services/storage_service.dart';

/// Owns the placemarks of the active chart. Mirrors [AnnotationState]: loads the
/// active chart's set, mutates in memory, and persists on every change so the
/// pilot's markers survive a restart and are available offline.
class WaypointState extends ChangeNotifier {
  WaypointState(this._storage);
  final StorageService _storage;

  String? _chartId;
  final List<Waypoint> _items = [];

  List<Waypoint> get items => List.unmodifiable(_items);
  int get count => _items.length;

  Future<void> loadForChart(String chartId) async {
    _chartId = chartId;
    _items
      ..clear()
      ..addAll(await _storage.loadWaypoints(chartId));
    notifyListeners();
  }

  /// Creates a waypoint at [wp] (id already assigned by the caller/editor).
  void add(Waypoint wp) {
    _items.add(wp);
    _persist();
    notifyListeners();
  }

  void update(Waypoint wp) {
    final i = _items.indexWhere((w) => w.id == wp.id);
    if (i < 0) return;
    _items[i] = wp;
    _persist();
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((w) => w.id == id);
    _persist();
    notifyListeners();
  }

  /// Fresh unique id for a new waypoint.
  static String newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  void _persist() {
    final id = _chartId;
    if (id != null) _storage.saveWaypoints(id, _items);
  }
}
