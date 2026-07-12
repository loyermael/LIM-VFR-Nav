import 'package:flutter/material.dart';

/// Day and Night themes.
///
/// The Night theme is deliberately low-luminance with warm/red accents to
/// preserve the pilot's night vision during dusk and night flights, per the
/// UI spec. Both themes share large, well-spaced touch targets (see
/// [_baseButtonTheme]) so controls stay usable in turbulence.
class AppTheme {
  static const Color _vfrBlue = Color(0xFF1565C0);
  static const Color _nightAccent = Color(0xFFB0413E); // desaturated red

  static ThemeData get day => _build(
        brightness: Brightness.light,
        seed: _vfrBlue,
        scaffold: const Color(0xFFF3F4F6),
      );

  static ThemeData get night => _build(
        brightness: Brightness.dark,
        seed: _nightAccent,
        scaffold: const Color(0xFF05080D),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color seed,
    required Color scaffold,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      filledButtonTheme: _baseButtonTheme,
      textTheme: const TextTheme(
        // Instrument read-outs: tabular, high-contrast, large.
        headlineMedium: TextStyle(
          fontFeatures: [FontFeature.tabularFigures()],
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Big buttons — minimum 64x64 hit area, generous padding.
  static final FilledButtonThemeData _baseButtonTheme = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(64, 64),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
