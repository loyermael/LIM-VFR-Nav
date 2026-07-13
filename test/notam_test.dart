import 'package:flutter_test/flutter_test.dart';

import 'package:lim_vfr_nav/core/notam_filter.dart';
import 'package:lim_vfr_nav/core/notam_parser.dart';
import 'package:lim_vfr_nav/services/notam_source.dart';

void main() {
  group('Q-line coordinate parsing', () {
    test('decodes DDMM lat, DDDMM lon and NM radius', () {
      final c = NotamParser.parseCoordinates('4523N00450E010')!;
      expect(c.center.latitude, closeTo(45 + 23 / 60, 1e-6));
      expect(c.center.longitude, closeTo(4 + 50 / 60, 1e-6));
      expect(c.radiusNm, 10);
    });

    test('handles southern/western hemispheres', () {
      final c = NotamParser.parseCoordinates('3345S07030W025')!;
      expect(c.center.latitude, closeTo(-(33 + 45 / 60), 1e-6));
      expect(c.center.longitude, closeTo(-(70 + 30 / 60), 1e-6));
      expect(c.radiusNm, 25);
    });

    test('rejects malformed tokens', () {
      expect(NotamParser.parseCoordinates('NONSENSE'), isNull);
      expect(NotamParser.parseCoordinates('4523N00450E'), isNull); // no radius
    });
  });

  group('full NOTAM parsing', () {
    const raw = '''
A1234/26 NOTAMN
Q) LFFF/QRTCA/IV/BO/W/000/050/4523N00450E010
A) LFXX B) 2601011400 C) 2601011600
E) ZRT ACTIVE DRONE (UAV).''';

    test('extracts id, geometry, validity and scope', () {
      final n = NotamParser.parseNotam(raw)!;
      expect(n.id, 'A1234/26');
      expect(n.qCode, 'QRTCA');
      expect(n.subject, 'RT');
      expect(n.center.latitude, closeTo(45.3833, 1e-3));
      expect(n.radiusNm, 10);
      expect(n.isZone, isTrue);
      expect(n.startValid, DateTime.utc(2026, 1, 1, 14, 0));
      expect(n.endValid, DateTime.utc(2026, 1, 1, 16, 0));
    });

    test('activeAt respects the B)/C) window', () {
      final n = NotamParser.parseNotam(raw)!;
      expect(n.activeAt(DateTime.utc(2026, 1, 1, 15, 0)), isTrue);
      expect(n.activeAt(DateTime.utc(2026, 1, 1, 10, 0)), isFalse);
      expect(n.activeAt(DateTime.utc(2026, 1, 1, 17, 0)), isFalse);
    });
  });

  test('sample source parses and VFR filter drops the IFR (ILS) NOTAM',
      () async {
    final raw = await SampleNotamSource().fetchRaw();
    final all = NotamParser.parseMany(raw);
    expect(all.length, 4);
    final vfr = NotamFilter.vfrOnly(all);
    expect(vfr.length, 3); // QIGCA (subject "IG") filtered out
    expect(vfr.any((n) => n.subject == 'IG'), isFalse);
  });
}
