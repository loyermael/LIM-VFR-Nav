import 'package:latlong2/latlong.dart';

import '../models/airfield.dart';

/// Bundled **sample** aerodromes around Lyon (offline reference for the
/// long-press "Infos" popup). Illustrative frequencies/elevations — replace
/// with an OpenAIP/SIA dataset (P3 epic) for real use.
class AirfieldData {
  static const List<Airfield> all = [
    Airfield(
      icao: 'LFLL',
      name: 'Lyon Saint-Exupéry',
      position: LatLng(45.7263, 5.0908),
      elevationFt: 821,
      freqs: [
        RadioFreq('ATIS', '123.475'),
        RadioFreq('TWR', '120.550'),
        RadioFreq('APP', '120.150'),
        RadioFreq('GND', '121.900'),
      ],
    ),
    Airfield(
      icao: 'LFLY',
      name: 'Lyon Bron',
      position: LatLng(45.7272, 4.9444),
      elevationFt: 659,
      freqs: [
        RadioFreq('ATIS', '124.575'),
        RadioFreq('TWR', '118.200'),
        RadioFreq('APP', '120.150'),
      ],
    ),
    Airfield(
      icao: 'LFLU',
      name: 'Valence-Chabeuil',
      position: LatLng(44.9216, 4.9699),
      elevationFt: 525,
      freqs: [
        RadioFreq('AFIS', '119.300'),
        RadioFreq('A/A', '119.300'),
      ],
    ),
    Airfield(
      icao: 'LFLB',
      name: 'Chambéry-Aix',
      position: LatLng(45.6381, 5.8800),
      elevationFt: 779,
      freqs: [
        RadioFreq('ATIS', '124.175'),
        RadioFreq('TWR', '118.300'),
      ],
    ),
  ];

  /// The nearest field within [maxNm] of [p], or null.
  static Airfield? nearest(LatLng p, {double maxNm = 5}) {
    Airfield? best;
    var bestNm = maxNm;
    for (final a in all) {
      final d = a.distanceNmFrom(p);
      if (d <= bestNm) {
        bestNm = d;
        best = a;
      }
    }
    return best;
  }
}
