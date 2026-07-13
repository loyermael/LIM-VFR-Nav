import 'package:latlong2/latlong.dart';

import '../models/airspace.dart';
import 'units.dart';

/// One sample along the projected flight path: cumulative distance (NM) from the
/// aircraft and the position there.
class ProfileSample {
  final double distNm;
  final LatLng pos;
  const ProfileSample(this.distNm, this.pos);
}

/// A rectangle on the vertical-profile chart: an airspace crossed between
/// [xStartNm] and [xEndNm] along the path, spanning its floor→ceiling.
class ProfileBox {
  final Airspace airspace;
  final double xStartNm;
  final double xEndNm;
  const ProfileBox(this.airspace, this.xStartNm, this.xEndNm);
}

enum ThreatKind { inside, imminent }

class AirspaceThreat {
  final Airspace airspace;
  final ThreatKind kind;
  const AirspaceThreat(this.airspace, this.kind);
}

/// Airspace geometry algorithms for the vertical profile and proximity alerts.
///
/// The two headline routines requested:
///   * [verticalProfile] — turns the forward flight path into distance-vs-
///     altitude boxes, one per airspace segment crossed.
///   * [detectThreats] — flags controlled/forbidden airspaces the aircraft is
///     inside, or will enter within the look-ahead, at its current level.
class AirspaceGeo {
  AirspaceGeo._();

  /// Samples the straight-ahead path from [origin] along [trackDeg] at
  /// [speedMps] for [minutes], one point every [stepSec] seconds. Returns
  /// cumulative-distance samples (starting at 0 NM = the aircraft).
  static List<ProfileSample> sampleTrack(
    LatLng origin,
    double trackDeg,
    double speedMps, {
    int minutes = 20,
    int stepSec = 20,
  }) {
    final samples = <ProfileSample>[ProfileSample(0, origin)];
    final totalSec = minutes * 60;
    for (var s = stepSec; s <= totalSec; s += stepSec) {
      final meters = speedMps * s;
      samples.add(ProfileSample(
        Units.metersToNm(meters),
        Units.destination(origin, trackDeg, meters),
      ));
    }
    return samples;
  }

  /// VERTICAL PROFILE (pseudo-code made real):
  ///
  ///   for each airspace a:
  ///     inside ← false ; start ← null
  ///     for each sample s along the path:
  ///       here ← a.containsHorizontal(s.pos)
  ///       if here and not inside:  inside ← true ; start ← s.dist   (entry)
  ///       if not here and inside:  inside ← false ; emit box(a, start, s.dist)
  ///     if inside: emit box(a, start, lastDist)              (exit past horizon)
  ///
  /// Each emitted box spans the airspace's floor→ceiling vertically, so the
  /// panel draws it as a coloured rectangle over [xStart..xEnd] × [floor..ceil].
  static List<ProfileBox> verticalProfile(
    List<ProfileSample> path,
    Iterable<Airspace> airspaces,
  ) {
    final boxes = <ProfileBox>[];
    for (final a in airspaces) {
      var inside = false;
      double? start;
      for (final s in path) {
        final here = a.containsHorizontal(s.pos);
        if (here && !inside) {
          inside = true;
          start = s.distNm;
        } else if (!here && inside) {
          inside = false;
          boxes.add(ProfileBox(a, start!, s.distNm));
        }
      }
      if (inside && start != null) {
        boxes.add(ProfileBox(a, start, path.last.distNm));
      }
    }
    return boxes;
  }

  /// PROXIMITY / PENETRATION DETECTION:
  ///
  ///   ahead ← destination(pos, track, gs · lookahead)      // e.g. 2-min point
  ///   for each controlled/forbidden airspace a at our level:
  ///     if a.containsHorizontal(pos):           threat(a, INSIDE)
  ///     else if segment(pos→ahead) crosses a:   threat(a, IMMINENT)
  ///
  /// "At our level" = current altitude within the airspace band ± [vertMarginFt]
  /// (so we don't warn about a TMA 3000 ft above us). Needs a valid track/speed
  /// for the IMMINENT test; INSIDE is checked regardless.
  static List<AirspaceThreat> detectThreats(
    LatLng pos,
    double altFt,
    double trackDeg,
    double gsMps,
    Iterable<Airspace> airspaces, {
    int lookaheadSec = 120,
    double vertMarginFt = 200,
    bool trackValid = true,
  }) {
    final ahead =
        Units.destination(pos, trackDeg, gsMps * lookaheadSec);
    final out = <AirspaceThreat>[];
    for (final a in airspaces) {
      if (!a.isControlledOrForbidden) continue;
      if (!a.containsVertical(altFt, marginFt: vertMarginFt)) continue;
      if (a.containsHorizontal(pos)) {
        out.add(AirspaceThreat(a, ThreatKind.inside));
      } else if (trackValid && gsMps > 2 && a.crossedBySegment(pos, ahead)) {
        out.add(AirspaceThreat(a, ThreatKind.imminent));
      }
    }
    return out;
  }
}
