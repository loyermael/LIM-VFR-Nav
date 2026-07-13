import '../models/notam.dart';

/// Severity used to colour NOTAM markers and plain-language chips.
enum NotamSeverity { high, medium, low }

/// A recognised plain-language tag distilled from a NOTAM's jargon.
class NotamTag {
  final String label; // human, French
  final NotamSeverity severity;
  const NotamTag(this.label, this.severity);
}

/// Turns NOTAM jargon into short human tags, so the pilot doesn't decode raw
/// aeronautical text in flight. Pattern-matches the E) message (and Q-code).
class NotamLanguage {
  NotamLanguage._();

  static final List<(RegExp, NotamTag)> _rules = [
    (RegExp(r'RWY.*(CLSD|CLOSED)|PISTE.*FERM', caseSensitive: false),
        const NotamTag('Piste fermée', NotamSeverity.high)),
    (RegExp(r'\b(UAV|UAS|RPAS|DRONE)\b', caseSensitive: false),
        const NotamTag('Drone / UAV', NotamSeverity.high)),
    (RegExp(r'\b(ZRT|ZIT|ZDT|PROHIBITED|RESTRICTED|DANGER)\b|ACTIV',
            caseSensitive: false),
        const NotamTag('Zone active', NotamSeverity.high)),
    (RegExp(r'\b(OBST|OBSTACLE|CRANE|GRUE)\b', caseSensitive: false),
        const NotamTag('Obstacle', NotamSeverity.medium)),
    (RegExp(r'TWY.*(CLSD|CLOSED)|TAXIWAY.*FERM', caseSensitive: false),
        const NotamTag('Taxiway fermé', NotamSeverity.medium)),
    (RegExp(r'\b(100LL|AVGAS|JET\s?A1|FUEL|CARBURANT)\b', caseSensitive: false),
        const NotamTag('Carburant', NotamSeverity.medium)),
    (RegExp(r'\b(U/S|UNSERVICEABLE|HS|INOP)\b', caseSensitive: false),
        const NotamTag('Hors service', NotamSeverity.medium)),
    (RegExp(r'PARA|PARACHUT|BALLON|BALLOON|VOLTIGE|AEROBATIC|FIREWORK|ARTIFICE',
            caseSensitive: false),
        const NotamTag('Activité aérienne', NotamSeverity.medium)),
  ];

  /// All tags matched in a NOTAM's message, most severe first.
  static List<NotamTag> tags(Notam n) {
    final hay = '${n.text} ${n.qCode}';
    final found = <NotamTag>[];
    for (final (re, tag) in _rules) {
      if (re.hasMatch(hay)) found.add(tag);
    }
    found.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return found;
  }

  /// The single most important tag (for the marker colour), or a generic one.
  static NotamTag headline(Notam n) {
    final t = tags(n);
    if (t.isNotEmpty) return t.first;
    return n.isZone
        ? const NotamTag('Zone NOTAM', NotamSeverity.high)
        : const NotamTag('NOTAM', NotamSeverity.low);
  }

  static NotamSeverity severity(Notam n) => headline(n).severity;
}
