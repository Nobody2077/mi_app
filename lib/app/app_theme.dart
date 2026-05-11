import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color primary = Color(0xFFE89A00);
  static const Color secondary = Color(0xFF22577A);
  static const Color minibus = Color(0xFF22577A);
  static const Color trufi = Color(0xFF2D936C);
  static const Color micro = Color(0xFFE89A00);
  static const Color modified = Color(0xFFC2410C);

  static const Color _lightBackground = Color(0xFFFFF8E8);
  static const Color _lightSurface = Color(0xFFFFEFC6);
  static const Color _lightCard = Color(0xFFFFF3D4);
  static const Color _darkBackground = Color(0xFF0F172A);
  static const Color _darkSurface = Color(0xFF182235);
  static const Color _darkCard = Color(0xFF223047);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: _lightSurface,
      error: modified,
      brightness: Brightness.light,
    );

    return _theme(scheme).copyWith(
      scaffoldBackgroundColor: _lightBackground,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: primary,
        foregroundColor: Color(0xFF1C1400),
        elevation: 0,
      ),
      cardTheme: _cardTheme(_lightCard, Colors.black.withValues(alpha: 0.08)),
      inputDecorationTheme: _inputTheme(
        fillColor: const Color(0xFFFFF2CF),
        borderColor: Colors.black.withValues(alpha: 0.16),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: const Color(0xFFFFB833),
      secondary: const Color(0xFF7CC5E8),
      surface: _darkSurface,
      error: const Color(0xFFFF8A50),
      brightness: Brightness.dark,
    );

    return _theme(scheme).copyWith(
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Color(0xFF162033),
        foregroundColor: Color(0xFFFFE9B0),
        elevation: 0,
      ),
      cardTheme: _cardTheme(_darkCard, Colors.white.withValues(alpha: 0.08)),
      inputDecorationTheme: _inputTheme(
        fillColor: const Color(0xFF1D2A3F),
        borderColor: Colors.white.withValues(alpha: 0.16),
      ),
    );
  }

  static ThemeData _theme(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 14),
    );
  }

  static CardThemeData _cardTheme(Color color, Color borderColor) {
    return CardThemeData(
      color: color,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor),
      ),
    );
  }

  static InputDecorationTheme _inputTheme({
    required Color fillColor,
    required Color borderColor,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
    );
  }
}
