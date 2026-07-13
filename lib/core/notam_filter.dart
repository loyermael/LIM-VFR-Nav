import '../models/notam.dart';

/// Keeps only the NOTAMs a VFR pilot actually cares about, so the map isn't
/// buried under IFR/airline noise.
///
/// Heuristics (deliberately lenient — better to keep a borderline one than hide
/// a real hazard):
///   * drop anything whose LOWER limit is above FL195 (upper airspace, IFR);
///   * drop Q-code subjects starting with `I` (instrument/ILS/MLS) or `P`
///     (IFR air-traffic procedures — approach/SID/STAR minutiae);
///   * keep the rest: areas (R/W), obstacles (O), movement-area/runway (M),
///     services & fuel (F), lighting (L), etc.
class NotamFilter {
  static const int _vfrCeilingFl = 195;
  static const Set<String> _ifrSubjectFirstLetters = {'I', 'P'};

  static bool isVfrRelevant(Notam n) {
    if (n.lowerFl > _vfrCeilingFl) return false;
    final s = n.subject;
    if (s.isNotEmpty && _ifrSubjectFirstLetters.contains(s[0])) return false;
    return true;
  }

  static List<Notam> vfrOnly(Iterable<Notam> all) =>
      all.where(isVfrRelevant).toList();
}
