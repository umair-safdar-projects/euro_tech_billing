import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const navy = Color(0xFF102A43);
  static const blue = Color(0xFF1D4ED8);
  static const canvas = Color(0xFFF5F7FA);
  static const border = Color(0xFFD9E2EC);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
      primary: navy,
      secondary: blue,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Segoe UI',
      dividerColor: border,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: border),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
