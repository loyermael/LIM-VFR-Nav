import 'dart:ui' show Color;

import 'package:latlong2/latlong.dart';

/// A freehand pen stroke drawn on the scratchpad layer.
///
/// Points are stored in geographic coordinates (Lat/Lng), NOT screen pixels, so
/// the stroke stays anchored to the ground when the pilot pans or zooms — it is
/// a vector overlay, per the spec. Stroke width is kept in logical pixels so a
/// highlight stays legibly thick at every zoom level.
class Stroke {
  final List<LatLng> points;
  final int colorValue; // ARGB, stored as int for easy JSON persistence
  final double widthPx;

  const Stroke({
    required this.points,
    required this.colorValue,
    required this.widthPx,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'c': colorValue,
        'w': widthPx,
        'p': points.map((e) => [e.latitude, e.longitude]).toList(),
      };

  factory Stroke.fromJson(Map<String, dynamic> j) => Stroke(
        colorValue: j['c'] as int,
        widthPx: (j['w'] as num).toDouble(),
        points: (j['p'] as List)
            .map((e) => LatLng(
                  (e[0] as num).toDouble(),
                  (e[1] as num).toDouble(),
                ))
            .toList(),
      );
}

/// The palette offered by the drawing toolbar (spec: red / blue / fluo-yellow).
class PenColors {
  PenColors._();
  static const int red = 0xFFE53935;
  static const int blue = 0xFF1E88E5;
  static const int yellow = 0xFFFFEB3B;
  static const List<int> palette = [red, blue, yellow];
}
