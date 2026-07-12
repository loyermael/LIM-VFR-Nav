import 'package:flutter/foundation.dart';

import '../models/aircraft_profile.dart';
import '../services/storage_service.dart';

/// Owns the saved aircraft profiles and which one is active. The active profile
/// is the single source of performance data (TAS, glide ratio, fuel burn) for
/// the rest of the app — glide ring, wind estimation, planning.
class AircraftState extends ChangeNotifier {
  AircraftState(this._storage)
      : _profiles = _storage.loadAircraftProfiles(),
        _activeId = _storage.activeAircraftId;

  final StorageService _storage;
  final List<AircraftProfile> _profiles;
  String? _activeId;

  List<AircraftProfile> get profiles => List.unmodifiable(_profiles);

  AircraftProfile? get active {
    if (_activeId == null) return null;
    final match = _profiles.where((p) => p.id == _activeId);
    return match.isEmpty ? null : match.first;
  }

  /// Convenience for consumers that only need the glide ratio (#14).
  double? get activeGlideRatio => active?.glideRatio;

  static String newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  void addOrUpdate(AircraftProfile p) {
    final i = _profiles.indexWhere((e) => e.id == p.id);
    if (i >= 0) {
      _profiles[i] = p;
    } else {
      _profiles.add(p);
      _activeId ??= p.id; // first profile becomes active
    }
    _persist();
    notifyListeners();
  }

  void remove(String id) {
    _profiles.removeWhere((p) => p.id == id);
    if (_activeId == id) _activeId = _profiles.isEmpty ? null : _profiles.first.id;
    _persist();
    notifyListeners();
  }

  void setActive(String id) {
    _activeId = id;
    _storage.activeAircraftId = id;
    notifyListeners();
  }

  void _persist() {
    _storage.saveAircraftProfiles(_profiles);
    _storage.activeAircraftId = _activeId;
  }
}
