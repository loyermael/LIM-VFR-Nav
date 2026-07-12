import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../models/annotation.dart';
import '../../state/annotation_state.dart';
import '../../state/tools_state.dart';

/// Renders the scratchpad strokes as geo-anchored polylines.
///
/// Because every stroke stores Lat/Lng points, flutter_map re-projects them on
/// each frame — so annotations stay glued to the ground through pan and zoom,
/// exactly like a vector overlay. Committed strokes and the one currently being
/// drawn are shown together for immediate feedback.
class StrokesLayer extends StatelessWidget {
  const StrokesLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final annot = context.watch<AnnotationState>();
    final all = <Stroke>[
      ...annot.strokes,
      if (annot.inProgress != null) annot.inProgress!,
    ];
    if (all.isEmpty) return const SizedBox.shrink();

    return PolylineLayer(
      polylines: [
        for (final s in all)
          Polyline(
            points: s.points,
            color: s.color,
            strokeWidth: s.widthPx,
            // Fluo-yellow reads as a highlighter; other colours as a marker pen.
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),
      ],
    );
  }
}

/// Transparent gesture catcher that turns finger movement into stroke points
/// while the Draw tool is active. When the tool is off it shrinks to nothing so
/// pan/zoom fall through to the map.
///
/// This is the ONLY place that converts screen -> geographic coordinates, via
/// [MapCamera.offsetToCrs] (rotation-aware). If you upgrade/downgrade
/// flutter_map and the projection call name changes, this is the single spot to
/// adjust.
class DrawingGestureLayer extends StatelessWidget {
  const DrawingGestureLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final drawing = context.select<ToolsState, bool>((t) => t.isDrawing);
    if (!drawing) return const SizedBox.shrink();

    final camera = MapCamera.of(context);
    final annot = context.read<AnnotationState>();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => annot.beginStroke(camera.offsetToCrs(d.localPosition)),
      onPanUpdate: (d) => annot.extendStroke(camera.offsetToCrs(d.localPosition)),
      onPanEnd: (_) => annot.endStroke(),
      child: const SizedBox.expand(),
    );
  }
}
