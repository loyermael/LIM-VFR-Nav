/// A saved aircraft configuration. Feeds flight computations elsewhere:
///  * [cruiseTasKts]  → wind estimation (#16), flight-plan timings.
///  * [glideRatio]    → glide range ring (#14) — the key glider parameter.
///  * [fuelBurnLph]   → endurance / fuel planning.
///
/// All performance fields are optional so a glider profile can set only the
/// glide ratio and a power profile only TAS/fuel.
class AircraftProfile {
  final String id;
  final String name;
  final double? cruiseTasKts;
  final double? glideRatio;
  final double? fuelBurnLph;

  const AircraftProfile({
    required this.id,
    required this.name,
    this.cruiseTasKts,
    this.glideRatio,
    this.fuelBurnLph,
  });

  AircraftProfile copyWith({
    String? name,
    double? cruiseTasKts,
    double? glideRatio,
    double? fuelBurnLph,
  }) =>
      AircraftProfile(
        id: id,
        name: name ?? this.name,
        cruiseTasKts: cruiseTasKts ?? this.cruiseTasKts,
        glideRatio: glideRatio ?? this.glideRatio,
        fuelBurnLph: fuelBurnLph ?? this.fuelBurnLph,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tas': cruiseTasKts,
        'glide': glideRatio,
        'fuel': fuelBurnLph,
      };

  factory AircraftProfile.fromJson(Map<String, dynamic> j) => AircraftProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        cruiseTasKts: (j['tas'] as num?)?.toDouble(),
        glideRatio: (j['glide'] as num?)?.toDouble(),
        fuelBurnLph: (j['fuel'] as num?)?.toDouble(),
      );
}
