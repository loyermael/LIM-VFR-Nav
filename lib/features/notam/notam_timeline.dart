import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/notam_state.dart';

/// "Flight time" slider: scrub from now-1h to now+12h; the map then shows only
/// the NOTAMs in force at that instant (so a zone active only 14:00–16:00 is
/// hidden if you scrub to 10:00). A tap on the clock resets to now.
class NotamTimeline extends StatelessWidget {
  const NotamTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<NotamState>();
    if (!st.visible || st.count == 0) return const SizedBox.shrink();

    final base = DateTime.now().subtract(const Duration(hours: 1));
    const spanMinutes = 13 * 60; // 1h back + 12h forward
    final offset =
        st.selectedTime.difference(base).inMinutes.clamp(0, spanMinutes);
    final activeCount = st.activeNow.length;

    final t = st.selectedTime.toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    final timeLabel = '${two(t.hour)}:${two(t.minute)}';
    final isNow = (DateTime.now().difference(st.selectedTime).inMinutes).abs() < 3;

    return SafeArea(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(isNow ? Icons.schedule : Icons.restore),
                tooltip: 'Maintenant',
                onPressed: st.resetTime,
              ),
              SizedBox(
                width: 92,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Heure de vol',
                        style: Theme.of(context).textTheme.labelSmall),
                    Text(isNow ? '$timeLabel (now)' : timeLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              Expanded(
                child: Slider(
                  min: 0,
                  max: spanMinutes.toDouble(),
                  value: offset.toDouble(),
                  onChanged: (v) => st.setSelectedTime(
                      base.add(Duration(minutes: v.round()))),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('$activeCount actifs'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
