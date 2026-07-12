import 'dart:ui' show Color;

import 'package:latlong2/latlong.dart';

/// A pilot-placed point of interest (placemark) anchored to a chart: a report
/// point, an obstacle, a field, a rendez-vous. Persisted per chart, like
/// [Stroke]s. Later phases target these with Direct-To and build routes from them.
class Waypoint {
  final String id;
  final String name;
  final LatLng position;
  final int colorValue; // ARGB
  final String note;

  const Waypoint({
    required this.id,
    required this.name,
    required this.position,
    required this.colorValue,
    this.note = '',
  });

  Color get color => Color(colorValue);

  Waypoint copyWith({
    String? name,
    LatLng? position,
    int? colorValue,
    String? note,
  }) =>
      Waypoint(
        id: id,
        name: name ?? this.name,
        position: position ?? this.position,
        colorValue: colorValue ?? this.colorValue,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': position.latitude,
        'lng': position.longitude,
        'c': colorValue,
        'note': note,
      };

  factory Waypoint.fromJson(Map<String, dynamic> j) => Waypoint(
        id: j['id'] as String,
        name: j['name'] as String,
        position: LatLng(
          (j['lat'] as num).toDouble(),
          (j['lng'] as num).toDouble(),
        ),
        colorValue: j['c'] as int,
        note: (j['note'] as String?) ?? '',
      );
}
