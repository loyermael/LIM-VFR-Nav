import 'package:latlong2/latlong.dart';

import '../models/notam.dart';

/// Parsing of ICAO NOTAM messages, focused on the geometry encoded in the
/// **Q-line** — the piece L!M VFR Nav needs to draw a NOTAM on the map.
///
/// A Q-line looks like:
///   Q) LFFF/QRTCA/IV/BO/W/000/050/4523N00450E005
///        │     │    │  │  │  │   │        └─ centre + radius (this module's target)
///        │     │    │  │  │  │   └─ upper limit (FL)
///        │     │    │  │  │  └─ lower limit (FL)
///        │     │    │  │  └─ scope (A/E/W)
///        │     │    │  └─ purpose (NBO/BO/M…)
///        │     │    └─ traffic (I/V/IV)
///        │     └─ Q-code (subject + condition)
///        └─ FIR
///
/// The last item, `4523N00450E005`, packs:
///   * latitude  DDMM + N/S      -> 45°23'N
///   * longitude DDDMM + E/W     -> 004°50'E
///   * radius    NNN nautical miles (000..999)
class NotamParser {
  /// Extracts the centre position and radius (NM) from the trailing
  /// coordinate token of a Q-line, e.g. `"4523N00450E005"`.
  ///
  /// Returns null if the token isn't the standard 11-char coord + 3-char radius
  /// shape. Latitude is DDMM (2°+2'), longitude DDDMM (3°+2'), radius 3 digits.
  static ({LatLng center, double radiusNm})? parseCoordinates(String token) {
    final m = RegExp(r'^(\d{2})(\d{2})([NS])(\d{3})(\d{2})([EW])(\d{3})$')
        .firstMatch(token.trim().toUpperCase());
    if (m == null) return null;

    final latDeg = int.parse(m.group(1)!);
    final latMin = int.parse(m.group(2)!);
    var lat = latDeg + latMin / 60.0;
    if (m.group(3) == 'S') lat = -lat;

    final lonDeg = int.parse(m.group(4)!);
    final lonMin = int.parse(m.group(5)!);
    var lon = lonDeg + lonMin / 60.0;
    if (m.group(6) == 'W') lon = -lon;

    final radiusNm = int.parse(m.group(7)!).toDouble();

    // Sanity: reject impossible coordinates.
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return (center: LatLng(lat, lon), radiusNm: radiusNm);
  }

  /// Parses the 8 slash-separated fields of a Q-line body (without the "Q)").
  /// Tolerant: returns whatever it can extract.
  static _QLine? _parseQLine(String qBody) {
    final parts = qBody.trim().split('/');
    if (parts.length < 2) return null;
    final coords = parts.length >= 8 ? parseCoordinates(parts[7]) : null;
    return _QLine(
      fir: parts[0].trim(),
      qCode: parts.length > 1 ? parts[1].trim() : '',
      traffic: parts.length > 2 ? parts[2].trim() : '',
      scope: parts.length > 4 ? parts[4].trim() : '',
      lowerFl: parts.length > 5 ? int.tryParse(parts[5].trim()) ?? 0 : 0,
      upperFl: parts.length > 6 ? int.tryParse(parts[6].trim()) ?? 999 : 999,
      center: coords?.center,
      radiusNm: coords?.radiusNm ?? 0,
    );
  }

  /// Parses one full NOTAM text block into a [Notam], or null if it has no
  /// usable Q-line geometry. Recognises the standard item markers
  /// `Q) A) B) C) D) E) F) G)`.
  static Notam? parseNotam(String raw) {
    final flat = raw.replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
    if (flat.isEmpty) return null;

    final items = _splitItems(flat);
    final qBody = items['Q'];
    if (qBody == null) return null;
    final q = _parseQLine(qBody);
    if (q == null || q.center == null) return null;

    final id = RegExp(r'^([A-Z]\d{3,4}/\d{2})').firstMatch(flat)?.group(1) ??
        _idFallback(flat);

    final start = _parseDate(items['B']);
    if (start == null) return null;
    final cRaw = (items['C'] ?? '').trim().toUpperCase();
    final permanent = cRaw.startsWith('PERM');
    final end = permanent ? null : _parseDate(items['C']);

    return Notam(
      id: id,
      fir: q.fir,
      qCode: q.qCode,
      traffic: q.traffic,
      scope: q.scope,
      lowerFl: q.lowerFl,
      upperFl: q.upperFl,
      center: q.center!,
      radiusNm: q.radiusNm,
      aerodromes: (items['A'] ?? '')
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList(),
      startValid: start,
      endValid: end,
      permanent: permanent,
      hasSchedule: (items['D'] ?? '').trim().isNotEmpty,
      text: (items['E'] ?? '').trim(),
      raw: raw.trim(),
    );
  }

  /// Parses a blob possibly containing many NOTAMs (blank-line separated, or
  /// each starting with an id like "A1234/26").
  static List<Notam> parseMany(String blob) {
    final blocks = blob
        .split(RegExp(r'\n\s*\n|(?=\b[A-Z]\d{3,4}/\d{2}\s+NOTAM)'))
        .where((b) => b.trim().isNotEmpty);
    final out = <Notam>[];
    for (final b in blocks) {
      final n = parseNotam(b);
      if (n != null) out.add(n);
    }
    return out;
  }

  // --- helpers --------------------------------------------------------------

  /// Splits a flattened NOTAM into its item map by the `X)` markers.
  static Map<String, String> _splitItems(String flat) {
    final markers = RegExp(r'([A-GQ])\)\s');
    final result = <String, String>{};
    final matches = markers.allMatches(flat).toList();
    for (var i = 0; i < matches.length; i++) {
      final key = matches[i].group(1)!;
      final startIdx = matches[i].end;
      final endIdx = i + 1 < matches.length ? matches[i + 1].start : flat.length;
      result[key] = flat.substring(startIdx, endIdx).trim();
    }
    return result;
  }

  /// Parses a `YYMMDDHHMM` NOTAM timestamp (UTC).
  static DateTime? _parseDate(String? s) {
    if (s == null) return null;
    final m = RegExp(r'(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})').firstMatch(s.trim());
    if (m == null) return null;
    return DateTime.utc(
      2000 + int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
    );
  }

  static String _idFallback(String flat) =>
      flat.split(RegExp(r'\s')).firstWhere((w) => w.isNotEmpty,
          orElse: () => 'NOTAM');
}

class _QLine {
  final String fir;
  final String qCode;
  final String traffic;
  final String scope;
  final int lowerFl;
  final int upperFl;
  final LatLng? center;
  final double radiusNm;
  _QLine({
    required this.fir,
    required this.qCode,
    required this.traffic,
    required this.scope,
    required this.lowerFl,
    required this.upperFl,
    required this.center,
    required this.radiusNm,
  });
}
