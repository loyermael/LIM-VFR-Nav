import 'dart:ui' show Offset;

import 'package:latlong2/latlong.dart';

/// One georeference tie-point: an image pixel and the real-world coordinate it
/// corresponds to. Collected on the calibration screen.
class CalibrationPoint {
  /// Pixel coordinate in the source image (top-left origin, +y down).
  final Offset pixel;

  /// Real-world position the pilot assigned to that pixel.
  final LatLng world;

  const CalibrationPoint(this.pixel, this.world);

  Map<String, dynamic> toJson() => {
        'px': pixel.dx,
        'py': pixel.dy,
        'lat': world.latitude,
        'lng': world.longitude,
      };

  factory CalibrationPoint.fromJson(Map<String, dynamic> j) => CalibrationPoint(
        Offset((j['px'] as num).toDouble(), (j['py'] as num).toDouble()),
        LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
      );
}
