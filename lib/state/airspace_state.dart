import 'package:flutter/foundation.dart';

import '../models/airspace.dart';
import '../services/airspace_data.dart';

/// Holds the airspace set and the two view toggles: draw airspaces on the map,
/// and show the vertical-profile panel. Airspaces are bundled sample data for
/// now (see [SampleAirspaceData]); a real OpenAIP/SIA import lands in P3.
class AirspaceState extends ChangeNotifier {
  List<Airspace> _airspaces = SampleAirspaceData.all();
  bool _showAirspaces = true;
  bool _showProfile = false;

  List<Airspace> get airspaces => List.unmodifiable(_airspaces);
  bool get showAirspaces => _showAirspaces;
  bool get showProfile => _showProfile;

  void toggleAirspaces() {
    _showAirspaces = !_showAirspaces;
    notifyListeners();
  }

  void toggleProfile() {
    _showProfile = !_showProfile;
    notifyListeners();
  }

  void replaceAll(List<Airspace> list) {
    _airspaces = List.of(list);
    notifyListeners();
  }
}
