import 'package:flutter/material.dart';

/// A large, high-contrast, easy-to-hit map control. Sized generously (min 60px)
/// so it stays usable with gloves and in turbulence, per the UI spec.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: active ? cs.primary : cs.surface.withValues(alpha: 0.9),
          shape: const CircleBorder(),
          elevation: 3,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 60,
              height: 60,
              child: Icon(
                icon,
                size: 30,
                color: active ? cs.onPrimary : cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
