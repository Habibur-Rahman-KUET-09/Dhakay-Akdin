import 'package:flutter/material.dart';

/// Rickshaw-art palette (docs/DETAILED_DESIGN.md §১০): bright, flat colours
/// with thick dark outlines, on a warm cream background.
class Palette {
  static const magenta = Color(0xFFC2185B);
  static const parrot = Color(0xFF2E9E6B);
  static const yellow = Color(0xFFF6B800);
  static const sky = Color(0xFF2D8BD6);
  static const vermilion = Color(0xFFE2432A);
  static const outline = Color(0xFF1D1A1A);
  static const cream = Color(0xFFFFF6E5);
}

class GameTheme {
  static const font = 'HindSiliguri';

  static ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.magenta,
      primary: Palette.magenta,
      secondary: Palette.parrot,
      tertiary: Palette.yellow,
      surface: Palette.cream,
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: font,
    );
    return base.copyWith(
      scaffoldBackgroundColor: Palette.cream,
      textTheme: base.textTheme.apply(
        bodyColor: Palette.outline,
        displayColor: Palette.outline,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(
            fontFamily: font,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Palette.outline, width: 3),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Palette.outline, width: 3),
        ),
      ),
    );
  }
}
