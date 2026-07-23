import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OpenAirColors {
  static const background = Color(0xFF0A0A0A);
  static const surface = Color(0xFF141414);
  static const surfaceElevated = Color(0xFF1C1C1C);
  static const border = Color(0xFF2A2A2A);
  static const textPrimary = Color(0xFFF2F2F2);
  static const textSecondary = Color(0xFF9A9A9A);
  static const textMuted = Color(0xFF6B6B6B);

  static const recovery = Color(0xFF3DDC97);
  static const strain = Color(0xFFF5C842);
  static const sleep = Color(0xFF5B8DEF);
  static const heart = Color(0xFFE85D5D);
  static const spo2 = Color(0xFF4ECDC4);
}

class OpenAirTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: OpenAirColors.background,
      colorScheme: const ColorScheme.dark(
        surface: OpenAirColors.surface,
        primary: OpenAirColors.recovery,
        secondary: OpenAirColors.sleep,
        error: OpenAirColors.heart,
        onSurface: OpenAirColors.textPrimary,
      ),
    );

    final textTheme = GoogleFonts.dmSansTextTheme(base.textTheme).apply(
      bodyColor: OpenAirColors.textPrimary,
      displayColor: OpenAirColors.textPrimary,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: OpenAirColors.background,
        foregroundColor: OpenAirColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: OpenAirColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: OpenAirColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: OpenAirColors.border),
        ),
      ),
      dividerColor: OpenAirColors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OpenAirColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OpenAirColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OpenAirColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OpenAirColors.recovery),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: OpenAirColors.surfaceElevated,
        contentTextStyle: GoogleFonts.dmSans(color: OpenAirColors.textPrimary),
      ),
    );
  }
}
