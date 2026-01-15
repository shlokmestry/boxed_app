import 'package:flutter/material.dart';

class AppTheme {
  static const String? _fontFamily = null; // put 'Inter' when you add it

  static const Color _darkBg = Color(0xFF000000);
  static const Color _darkSurface = Color(0xFF222222);
  static const Color _lightBg = Color(0xFFFFFFFF);
  static const Color _lightSurface = Color(0xFFF4F4F4);

  static ThemeData light() {
    final base = ThemeData.light();

    return base.copyWith(
      scaffoldBackgroundColor: _lightBg,
      colorScheme: const ColorScheme.light(
        primary: Colors.black,
        onPrimary: Colors.white,
        background: _lightBg,
        onBackground: Colors.black,
        surface: _lightSurface,
        onSurface: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBg,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      // ✅ apply font family here (this works)
      textTheme: _textTheme(base.textTheme, isDark: false).apply(
        fontFamily: _fontFamily,
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark();

    return base.copyWith(
      scaffoldBackgroundColor: _darkBg,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        onPrimary: Colors.black,
        background: _darkBg,
        onBackground: Colors.white,
        surface: _darkSurface,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      // ✅ apply font family here (this works)
      textTheme: _textTheme(base.textTheme, isDark: true).apply(
        fontFamily: _fontFamily,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, {required bool isDark}) {
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
