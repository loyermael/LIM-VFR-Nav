import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/wind_estimator.dart';
import '../models/flight_state.dart';
import '../models/wind.dart';
import '../services/location_service.dart';

/// Live navigation state: the latest GPS fix plus the two display modes that
/// affect how the map tracks the aircraft.
class NavState extends ChangeNotifier {
  NavState(this._location);
  final LocationService _location;
  StreamSubscription<FlightState>? _sub;

  FlightState _flight = FlightState.noFix();
  FlightState get flight => _flight;

  final WindEstimator _windEstimator = WindEstimator();

  /// Latest GPS-circling wind estimate (#16), or null until a full circle has
  /// been flown. Stays available afterwards until reset.
  WindEstimate? get wind => _windEstimator.last;

  /// Keep the aircraft centred as it moves.
  bool _followAircraft = true;
  bool get followAircraft => _followAircraft;

  /// Rotate the map so the current track points up (vs. North-Up).
  bool _trackUp = false;
  bool get trackUp => _trackUp;

  void start() {
    _sub = _location.stream().listen((f) {
      _flight = f;
      _windEstimator.add(f); // updates the circling-wind estimate
      notifyListeners();
    });
  }

  void setFollow(bool v) {
    _followAircraft = v;
    notifyListeners();
  }

  void toggleTrackUp() {
    _trackUp = !_trackUp;
    notifyListeners();
  }

  /// Map rotation to apply, in degrees. North-Up = 0. In Track-Up we rotate the
  /// map by -track so the flown direction is at the top.
  double get mapRotation {
    if (!_trackUp || !_flight.hasValidTrack) return 0;
    return -_flight.trackDeg;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _location.dispose();
    super.dispose();
  }
}
