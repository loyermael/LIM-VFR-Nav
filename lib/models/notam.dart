import 'package:latlong2/latlong.dart';

/// ICAO scope of a NOTAM (5th field of the Q-line: A/E/W/AE/…).
enum NotamScope { aerodrome, enRoute, warning, mixed, unknown }

/// A parsed NOTAM (Notice to Airmen). Geometry (centre + radius) comes from the
/// Q-line; validity from the B)/C) fields; the human message from E). Persisted
/// locally so the whole set is available offline in flight.
class Notam {
  final String id; // e.g. "A1234/26"
  final String fir; // e.g. "LFFF"
  final String qCode; // 5 chars incl. leading Q, e.g. "QRTCA"
  final String traffic; // IV / I / V
  final String scope; // raw scope letters, e.g. "W", "AE"
  final int lowerFl; // flight level, 000..999
  final int upperFl;
  final LatLng center; // from Q-line coordinates
  final double radiusNm; // from Q-line radius
  final List<String> aerodromes; // A) items (ICAO)
  final DateTime startValid; // B)
  final DateTime? endValid; // C) (null when permanent)
  final bool permanent;
  final bool hasSchedule; // a D) time-schedule is present (not fully expanded)
  final String text; // E) plain message
  final String raw;

  const Notam({
    required this.id,
    required this.fir,
    required this.qCode,
    required this.traffic,
    required this.scope,
    required this.lowerFl,
    required this.upperFl,
    required this.center,
    required this.radiusNm,
    required this.aerodromes,
    required this.startValid,
    required this.endValid,
    required this.permanent,
    required this.hasSchedule,
    required this.text,
    required this.raw,
  });

  /// Q-code subject (2 letters) — what the NOTAM is about, e.g. "RT", "OB".
  String get subject => qCode.length >= 3 ? qCode.substring(1, 3) : '';

  /// Q-code condition/status (2 letters), e.g. "CA" (activated), "LC" (closed).
  String get condition => qCode.length >= 5 ? qCode.substring(3, 5) : '';

  NotamScope get scopeKind {
    final s = scope.toUpperCase();
    final a = s.contains('A'), e = s.contains('E'), w = s.contains('W');
    if (w && (a || e)) return NotamScope.mixed;
    if (w) return NotamScope.warning;
    if (a && e) return NotamScope.mixed;
    if (a) return NotamScope.aerodrome;
    if (e) return NotamScope.enRoute;
    return NotamScope.unknown;
  }

  /// Should be drawn as an area (translucent circle): warning/area scope with a
  /// meaningful radius.
  bool get isZone =>
      (scopeKind == NotamScope.warning || scopeKind == NotamScope.mixed) &&
      radiusNm > 0;

  /// Should get an aerodrome flag/marker.
  bool get isAerodrome =>
      scopeKind == NotamScope.aerodrome || scopeKind == NotamScope.mixed;

  /// True if this NOTAM is in force at [t] (B)/C) window). D) schedules aren't
  /// fully expanded — [hasSchedule] flags that the real active periods are finer.
  bool activeAt(DateTime t) {
    if (t.isBefore(startValid)) return false;
    if (permanent || endValid == null) return true;
    return !t.isAfter(endValid!);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fir': fir,
        'q': qCode,
        'traffic': traffic,
        'scope': scope,
        'lo': lowerFl,
        'up': upperFl,
        'lat': center.latitude,
        'lng': center.longitude,
        'r': radiusNm,
        'ad': aerodromes,
        'b': startValid.toIso8601String(),
        'c': endValid?.toIso8601String(),
        'perm': permanent,
        'sched': hasSchedule,
        'e': text,
        'raw': raw,
      };

  factory Notam.fromJson(Map<String, dynamic> j) => Notam(
        id: j['id'] as String,
        fir: j['fir'] as String? ?? '',
        qCode: j['q'] as String? ?? '',
        traffic: j['traffic'] as String? ?? '',
        scope: j['scope'] as String? ?? '',
        lowerFl: (j['lo'] as num?)?.toInt() ?? 0,
        upperFl: (j['up'] as num?)?.toInt() ?? 999,
        center: LatLng(
            (j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        radiusNm: (j['r'] as num?)?.toDouble() ?? 0,
        aerodromes: ((j['ad'] as List?) ?? const []).cast<String>(),
        startValid: DateTime.parse(j['b'] as String),
        endValid: j['c'] == null ? null : DateTime.parse(j['c'] as String),
        permanent: j['perm'] as bool? ?? false,
        hasSchedule: j['sched'] as bool? ?? false,
        text: j['e'] as String? ?? '',
        raw: j['raw'] as String? ?? '',
      );
}
