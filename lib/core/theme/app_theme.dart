import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData getTheme(Brightness brightness, String fontFamily) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFFAB40), // Orange Accent
        brightness: brightness,
        surface: brightness == Brightness.light
            ? const Color(0xFFFFF8E1) // Beige (Amber 50)
            : const Color(0xFF212121),
      ),
      fontFamily: fontFamily,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: brightness == Brightness.light ? Colors.transparent : null,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light ? Colors.white : Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: brightness == Brightness.light ? const Color(0xFFFFAB40) : const Color(0xFFFFCC80),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: brightness == Brightness.light ? Colors.grey.shade400 : Colors.grey.shade700,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: brightness == Brightness.light ? const Color(0xFFFFAB40) : const Color(0xFFFFCC80),
            width: 2,
          ),
        ),
      ),
    );
  }

  static ThemeData get lightTheme => getTheme(Brightness.light, 'Roboto');
  static ThemeData get darkTheme => getTheme(Brightness.dark, 'Roboto');
}
