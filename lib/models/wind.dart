/// A wind estimate produced from GPS while circling (#16).
///
/// [fromDeg] is the meteorological convention: the TRUE direction the wind blows
/// FROM. [speedKts] is its strength; [tasKts] is the true airspeed inferred as a
/// by-product (the radius of the fitted velocity circle).
class WindEstimate {
  final double fromDeg;
  final double speedKts;
  final double tasKts;
  final DateTime time;

  const WindEstimate({
    required this.fromDeg,
    required this.speedKts,
    required this.tasKts,
    required this.time,
  });
}
