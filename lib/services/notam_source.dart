import 'package:http/http.dart' as http;

/// A source of raw NOTAM text, queried **on the ground** (Wi-Fi/4G) before
/// flight. Implementations return a blob of raw ICAO NOTAM messages that the
/// parser turns into [Notam]s; the result is then stored for offline use.
abstract class NotamSource {
  String get name;
  Future<String> fetchRaw();
}

/// Generic HTTP source: GETs raw NOTAM text from [url] with optional [headers].
///
/// Real providers need credentials you supply here:
///   * **FAA** NOTAM API — OAuth `client_id`/`client_secret` (returns JSON;
///     adapt [transform] to pull the ICAO text out).
///   * **SIA France** / **Eurocontrol EAD** — account + token in [headers].
/// The parser only cares about the raw ICAO text, so any endpoint that yields
/// it works here.
class HttpNotamSource implements NotamSource {
  HttpNotamSource({
    required this.name,
    required this.url,
    this.headers = const {},
    this.transform,
  });

  @override
  final String name;
  final Uri url;
  final Map<String, String> headers;

  /// Optional hook to extract raw NOTAM text from a JSON/HTML payload.
  final String Function(String body)? transform;

  @override
  Future<String> fetchRaw() async {
    final res = await http.get(url, headers: headers);
    if (res.statusCode != 200) {
      throw Exception('NOTAM fetch ${res.statusCode} from $name');
    }
    return transform?.call(res.body) ?? res.body;
  }
}

/// Bundled sample NOTAMs (around Lyon) so the whole pipeline — parse, filter,
/// map display, timeline, proximity alert — can be exercised fully offline,
/// without any API credentials.
class SampleNotamSource implements NotamSource {
  @override
  String get name => 'Exemple (Lyon)';

  @override
  Future<String> fetchRaw() async => _sample;

  static const String _sample = '''
A1234/26 NOTAMN
Q) LFFF/QRTCA/IV/BO/W/000/050/4523N00450E010
A) LFXX B) 2601011400 C) 2601011600
E) ZONE REGLEMENTEE TEMPORAIRE (ZRT) ACTIVE POUR ACTIVITE DRONE (UAV) JUSQU'A 5000FT AMSL.
F) SFC G) 5000FT AMSL

A1240/26 NOTAMN
Q) LFFF/QMRLC/IV/NBO/A/000/999/4544N00505E005
A) LFLY B) 2601010600 C) 2612312359
E) RWY 16/34 FERMEE (CLSD) TRAVAUX.

A1255/26 NOTAMN
Q) LFFF/QOBCE/IV/M/AW/000/002/4546N00450E003
A) LFLL B) 2601010000 C) PERM
E) GRUE (CRANE) ERECTED 250FT AGL 4546N00450E. BALISEE.

A1300/26 NOTAMN
Q) LEDDDD/QIGCA/I/NBO/A/000/999/4400N00200E005
A) LFMN B) 2601010600 C) 2601312359
E) ILS RWY 04 U/S. (NOTAM IFR — doit etre filtre en VFR)
''';
}
