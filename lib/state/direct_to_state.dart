import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// The active Direct-To leg: a single destination the pilot is navigating
/// straight to. Ephemeral (not persisted) — it's a live intention, cleared when
/// reached or dismissed. Distance/track/ETE are derived on the fly from the
/// current [FlightState]; this only holds the target.
class DirectToState extends ChangeNotifier {
  LatLng? _target;
  String? _name;

  LatLng? get target => _target;
  String? get name => _name;
  bool get isActive => _target != null;

  void setTarget(LatLng target, {String? name}) {
    _target = target;
    _name = name;
    notifyListeners();
  }

  void clear() {
    _target = null;
    _name = null;
    notifyListeners();
  }
}
