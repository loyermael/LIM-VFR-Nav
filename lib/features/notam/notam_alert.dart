import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/units.dart';
import '../../models/notam.dart';
import '../../state/nav_state.dart';
import '../../state/notam_state.dart';

/// In-flight intrusion warning: if the aircraft's projected track will enter an
/// active zone NOTAM within the next 3 minutes, raise an audible + visual alert.
///
/// The check runs on each GPS fix (via a [NavState] listener, not during build).
/// A sound/haptic fires only when a *new* zone enters the alert set, so it
/// doesn't nag continuously.
class NotamAlert extends StatefulWidget {
  const NotamAlert({super.key});

  @override
  State<NotamAlert> createState() => _NotamAlertState();
}

class _NotamAlertState extends State<NotamAlert> {
  static const int _lookaheadSec = 180; // 3 minutes

  NavState? _nav;
  Set<String> _alertedIds = {};
  List<Notam> _current = [];

  @override
  void initState() {
    super.initState();
    _nav = context.read<NavState>()..addListener(_check);
  }

  @override
  void dispose() {
    _nav?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    final flight = _nav!.flight;
    if (!flight.hasFix || !flight.hasValidTrack) {
      if (_current.isNotEmpty && mounted) setState(() => _current = []);
      _alertedIds = {};
      return;
    }

    final pos = flight.position!;
    final ahead = Units.destination(
        pos, flight.trackDeg, flight.groundSpeedMps * _lookaheadSec);
    final now = DateTime.now();

    final alerting = <Notam>[];
    for (final n in context.read<NotamState>().all) {
      if (!n.isZone || !n.activeAt(now)) continue;
      final d = _segmentDistanceMeters(n.center, pos, ahead);
      if (d < Units.nmToMeters(n.radiusNm)) alerting.add(n);
    }

    final newIntrusion = alerting.any((n) => !_alertedIds.contains(n.id));
    if (newIntrusion) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    }
    _alertedIds = alerting.map((n) => n.id).toSet();
    if (mounted) setState(() => _current = alerting);
  }

  /// Great-circle-ish distance (m) from point [p] to segment [a]–[b], using a
  /// local equirectangular projection (accurate over the few-NM scales here).
  static double _segmentDistanceMeters(LatLng p, LatLng a, LatLng b) {
    final lat0 = a.latitude * math.pi / 180;
    double mx(LatLng q) => q.longitude * 111320.0 * math.cos(lat0);
    double my(LatLng q) => q.latitude * 111320.0;
    final px = mx(p), py = my(p);
    final ax = mx(a), ay = my(a);
    final bx = mx(b), by = my(b);
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  }

  @override
  Widget build(BuildContext context) {
    if (_current.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.yellowAccent, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'ALERTE : NOTAM actif devant — ${_current.map((n) => n.id).join(', ')}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
