import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/airspace_geo.dart';
import '../../core/units.dart';
import '../../state/airspace_state.dart';
import '../../state/nav_state.dart';
import 'airspace_layer.dart';

/// Retractable bottom panel showing a vertical cross-section of the airspace
/// along the aircraft's projected track for the next 20 minutes: altitude
/// (0–FL195) vs distance, with the airspaces crossed drawn as coloured boxes.
/// Penetrated controlled/forbidden airspaces blink red.
class VerticalProfilePanel extends StatefulWidget {
  const VerticalProfilePanel({super.key});

  @override
  State<VerticalProfilePanel> createState() => _VerticalProfilePanelState();
}

class _VerticalProfilePanelState extends State<VerticalProfilePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  static const int _minutes = 20;
  static const double _defaultCruiseKt = 90;

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asp = context.watch<AirspaceState>();
    if (!asp.showProfile) return const SizedBox.shrink();
    final flight = context.watch<NavState>().flight;

    List<ProfileBox> boxes = const [];
    Set<String> threatened = const {};
    double maxNm = Units.metersToNm(
        Units.knotsToMps(_defaultCruiseKt) * _minutes * 60);
    final altFt = flight.altitudeFeet;

    if (flight.hasFix) {
      final track = flight.trackDeg.isNaN ? 0.0 : flight.trackDeg;
      final speed = flight.groundSpeedMps > Units.knotsToMps(5)
          ? flight.groundSpeedMps
          : Units.knotsToMps(_defaultCruiseKt);
      final path = AirspaceGeo.sampleTrack(flight.position!, track, speed,
          minutes: _minutes);
      maxNm = path.last.distNm;
      boxes = AirspaceGeo.verticalProfile(path, asp.airspaces);
      threatened = AirspaceGeo.detectThreats(
        flight.position!,
        altFt,
        track,
        flight.groundSpeedMps,
        asp.airspaces,
        trackValid: flight.hasValidTrack,
      ).map((t) => t.airspace.name).toSet();
    }

    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        child: SizedBox(
          height: 180,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 12),
                  const Text('Coupe verticale — 20 min',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: context.read<AirspaceState>().toggleProfile,
                  ),
                ],
              ),
              Expanded(
                child: flight.hasFix
                    ? AnimatedBuilder(
                        animation: _blink,
                        builder: (_, __) => CustomPaint(
                          size: Size.infinite,
                          painter: _ProfilePainter(
                            boxes: boxes,
                            threatened: threatened,
                            maxNm: maxNm,
                            aircraftAltFt: altFt,
                            blink: _blink.value,
                            textColor:
                                Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      )
                    : const Center(child: Text('En attente du GPS…')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter({
    required this.boxes,
    required this.threatened,
    required this.maxNm,
    required this.aircraftAltFt,
    required this.blink,
    required this.textColor,
  });

  final List<ProfileBox> boxes;
  final Set<String> threatened;
  final double maxNm;
  final double aircraftAltFt;
  final double blink;
  final Color textColor;

  static const double maxAltFt = 19500; // FL195
  static const double _left = 40, _right = 8, _top = 6, _bottom = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final plotW = size.width - _left - _right;
    final plotH = size.height - _top - _bottom;
    double xPix(double nm) => _left + (nm / (maxNm <= 0 ? 1 : maxNm)) * plotW;
    double yPix(double ft) => _top + (1 - ft / maxAltFt) * plotH;

    final axis = Paint()
      ..color = textColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    final grid = Paint()
      ..color = textColor.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    // Altitude grid + labels every 5000 ft.
    for (var ft = 0.0; ft <= maxAltFt; ft += 5000) {
      final y = yPix(ft);
      canvas.drawLine(Offset(_left, y), Offset(size.width - _right, y), grid);
      _label(canvas, '${(ft / 1000).round()}k', Offset(2, y - 6), textColor);
    }
    // Distance ticks every 5 NM.
    for (var nm = 0.0; nm <= maxNm; nm += 5) {
      final x = xPix(nm);
      canvas.drawLine(Offset(x, _top), Offset(x, size.height - _bottom), grid);
      _label(canvas, '${nm.round()}', Offset(x - 6, size.height - _bottom + 2),
          textColor);
    }
    // Axes.
    canvas.drawLine(const Offset(_left, _top),
        Offset(_left, size.height - _bottom), axis);
    canvas.drawLine(Offset(_left, size.height - _bottom),
        Offset(size.width - _right, size.height - _bottom), axis);

    // Airspace boxes.
    for (final b in boxes) {
      final isThreat = threatened.contains(b.airspace.name);
      final base = AirspaceLayer.borderColor(b.airspace.klass);
      final rect = Rect.fromLTRB(
        xPix(b.xStartNm),
        yPix(b.airspace.ceilingFt.clamp(0, maxAltFt)),
        xPix(b.xEndNm),
        yPix(b.airspace.floorFt.clamp(0, maxAltFt)),
      );
      final fillAlpha = isThreat ? (0.20 + 0.35 * blink) : 0.18;
      canvas.drawRect(
          rect, Paint()..color = (isThreat ? Colors.red : base).withValues(alpha: fillAlpha));
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isThreat ? 2 : 1
          ..color = isThreat ? Colors.red : base,
      );
      _label(canvas, b.airspace.name, rect.topLeft + const Offset(2, 1),
          textColor, size: 9, max: rect.width - 2);
    }

    // Aircraft marker at x=0, current altitude.
    final ax = xPix(0), ay = yPix(aircraftAltFt.clamp(0, maxAltFt));
    canvas.drawCircle(Offset(ax, ay), 4, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(ax, ay), 4, Paint()..style = PaintingStyle.stroke..color = Colors.black);
    // "Now" vertical line.
    canvas.drawLine(Offset(ax, _top), Offset(ax, size.height - _bottom),
        Paint()..color = Colors.white.withValues(alpha: 0.5));
  }

  void _label(Canvas canvas, String text, Offset at, Color color,
      {double size = 10, double? max}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: max ?? 60);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_ProfilePainter old) =>
      old.blink != blink ||
      old.aircraftAltFt != aircraftAltFt ||
      old.boxes != boxes ||
      old.maxNm != maxNm;
}
