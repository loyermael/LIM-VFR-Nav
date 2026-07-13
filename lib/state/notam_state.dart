import 'package:flutter/foundation.dart';

import '../models/notam.dart';
import '../services/notam_repository.dart';
import '../services/notam_source.dart';

/// Holds the synced NOTAM set plus the two view controls: whether they're shown
/// on the map, and the "flight time" the timeline is scrubbed to (only NOTAMs
/// active at that instant are displayed).
class NotamState extends ChangeNotifier {
  NotamState(this._repo);
  final NotamRepository _repo;

  List<Notam> _all = [];
  bool _visible = true;
  bool _syncing = false;
  DateTime _selectedTime = DateTime.now();

  List<Notam> get all => List.unmodifiable(_all);
  bool get visible => _visible;
  bool get syncing => _syncing;
  DateTime get selectedTime => _selectedTime;
  DateTime? get syncedAt => _repo.syncedAt;
  int get count => _all.length;

  /// NOTAMs in force at the scrubbed time (what the map should show).
  List<Notam> get activeNow =>
      _all.where((n) => n.activeAt(_selectedTime)).toList();

  List<Notam> get activeZones => activeNow.where((n) => n.isZone).toList();

  Future<void> load() async {
    _all = await _repo.loadStored();
    notifyListeners();
  }

  Future<void> sync(NotamSource source) async {
    _syncing = true;
    notifyListeners();
    try {
      _all = await _repo.sync(source);
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> importRaw(String raw) async {
    _all = await _repo.importRaw(raw);
    notifyListeners();
  }

  Future<void> clear() async {
    await _repo.clear();
    _all = [];
    notifyListeners();
  }

  void setVisible(bool v) {
    _visible = v;
    notifyListeners();
  }

  void toggleVisible() => setVisible(!_visible);

  void setSelectedTime(DateTime t) {
    _selectedTime = t;
    notifyListeners();
  }

  /// Reset the timeline to "now".
  void resetTime() => setSelectedTime(DateTime.now());
}
