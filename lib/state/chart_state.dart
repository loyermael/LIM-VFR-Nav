import 'package:flutter/foundation.dart';

import '../models/chart.dart';
import '../services/chart_repository.dart';

/// Owns the imported chart library and which chart is currently displayed.
class ChartState extends ChangeNotifier {
  ChartState(this._repo);
  final ChartRepository _repo;

  List<ChartDoc> _charts = [];
  List<ChartDoc> get charts => List.unmodifiable(_charts);

  ChartDoc? _active;
  ChartDoc? get active => _active;

  Future<void> restoreLastChart() async {
    _charts = await _repo.list();
    if (_charts.isNotEmpty) {
      _active = _charts.firstWhere(
        (c) => c.isCalibrated,
        orElse: () => _charts.first,
      );
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    _charts = await _repo.list();
    // Keep the active reference pointing at the freshest copy.
    if (_active != null) {
      final match = _charts.where((c) => c.id == _active!.id);
      _active = match.isEmpty ? null : match.first;
    }
    notifyListeners();
  }

  void setActive(ChartDoc chart) {
    _active = chart;
    notifyListeners();
  }

  /// Persists a calibration/name change and updates the in-memory copy.
  Future<void> saveChart(ChartDoc chart) async {
    await _repo.update(chart);
    await refresh();
    if (_active?.id == chart.id) _active = chart;
    notifyListeners();
  }

  Future<void> deleteChart(ChartDoc chart) async {
    await _repo.delete(chart);
    if (_active?.id == chart.id) _active = null;
    await refresh();
  }
}
