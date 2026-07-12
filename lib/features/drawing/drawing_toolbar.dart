import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/annotation.dart';
import '../../state/annotation_state.dart';

/// The pen palette shown while the Draw tool is active: colour swatches, three
/// stroke widths, undo and clear. Large, spaced controls for gloved/turbulent
/// use, per the UI spec.
class DrawingToolbar extends StatelessWidget {
  const DrawingToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final annot = context.watch<AnnotationState>();
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final c in PenColors.palette)
              _Swatch(
                argb: c,
                selected: annot.penColor == c,
                onTap: () => annot.setColor(c),
              ),
            const SizedBox(width: 4),
            for (final w in const [3.0, 6.0, 12.0])
              _WidthDot(
                width: w,
                selected: annot.penWidth == w,
                onTap: () => annot.setWidth(w),
              ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              iconSize: 30,
              onPressed: annot.canUndo ? annot.undo : null,
              icon: const Icon(Icons.undo),
              tooltip: 'Annuler',
            ),
            IconButton.filledTonal(
              iconSize: 30,
              onPressed: annot.canUndo ? annot.clear : null,
              icon: const Icon(Icons.layers_clear),
              tooltip: 'Tout effacer',
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.argb, required this.selected, required this.onTap});
  final int argb;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Color(argb),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.black26,
            width: selected ? 4 : 2,
          ),
        ),
      ),
    );
  }
}

class _WidthDot extends StatelessWidget {
  const _WidthDot({required this.width, required this.selected, required this.onTap});
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
        ),
        child: Container(
          width: width + 6,
          height: width + 6,
          decoration: BoxDecoration(
            color: cs.onSurface,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
