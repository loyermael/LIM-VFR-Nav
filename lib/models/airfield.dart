import 'package:latlong2/latlong.dart';

import '../core/units.dart';

/// A radio frequency at a field. [type] is TWR/AFIS/A/A/APP/ATIS/GND…
class RadioFreq {
  final String type;
  final String mhz;
  const RadioFreq(this.type, this.mhz);
}

/// An aerodrome / ULM base with the info a VFR pilot taps for: name, ICAO,
/// elevation, and radio frequencies. Reference data, cached for offline use.
class Airfield {
  final String icao;
  final String name;
  final LatLng position;
  final double elevationFt;
  final List<RadioFreq> freqs;

  const Airfield({
    required this.icao,
    required this.name,
    required this.position,
    required this.elevationFt,
    required this.freqs,
  });

  double distanceNmFrom(LatLng p) =>
      Units.metersToNm(Units.distanceMeters(position, p));
}
