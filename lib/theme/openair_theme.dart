import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Black / green / white brand palette with light + dark surfaces.
class OpenAirColors extends ThemeExtension<OpenAirColors> {
  const OpenAirColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.green,
    required this.greenSoft,
    required this.heart,
    required this.sleep,
    required this.strain,
    required this.spo2,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color green;
  final Color greenSoft;
  final Color heart;
  final Color sleep;
  final Color strain;
  final Color spo2;

  // Convenience aliases used across the app
  Color get recovery => green;

  static const dark = OpenAirColors(
    background: Color(0xFF000000),
    surface: Color(0xFF111111),
    surfaceElevated: Color(0xFF1A1A1A),
    border: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0B0B0),
    textMuted: Color(0xFF7A7A7A),
    green: Color(0xFF00E676),
    greenSoft: Color(0xFF1B5E20),
    heart: Color(0xFFFF5252),
    sleep: Color(0xFF69F0AE),
    strain: Color(0xFFB2FF59),
    spo2: Color(0xFF00C853),
  );

  static const light = OpenAirColors(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F7F5),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFDCE5DC),
    textPrimary: Color(0xFF0A0A0A),
    textSecondary: Color(0xFF4A554A),
    textMuted: Color(0xFF7A857A),
    green: Color(0xFF00C853),
    greenSoft: Color(0xFFE8F5E9),
    heart: Color(0xFFE53935),
    sleep: Color(0xFF2E7D32),
    strain: Color(0xFF43A047),
    spo2: Color(0xFF00A844),
  );

  static OpenAirColors of(BuildContext context) {
    return Theme.of(context).extension<OpenAirColors>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  @override
  OpenAirColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? green,
    Color? greenSoft,
    Color? heart,
    Color? sleep,
    Color? strain,
    Color? spo2,
  }) {
    return OpenAirColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      green: green ?? this.green,
      greenSoft: greenSoft ?? this.greenSoft,
      heart: heart ?? this.heart,
      sleep: sleep ?? this.sleep,
      strain: strain ?? this.strain,
      spo2: spo2 ?? this.spo2,
    );
  }

  @override
  OpenAirColors lerp(ThemeExtension<OpenAirColors>? other, double t) {
    if (other is! OpenAirColors) return this;
    return OpenAirColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      green: Color.lerp(green, other.green, t)!,
      greenSoft: Color.lerp(greenSoft, other.greenSoft, t)!,
      heart: Color.lerp(heart, other.heart, t)!,
      sleep: Color.lerp(sleep, other.sleep, t)!,
      strain: Color.lerp(strain, other.strain, t)!,
      spo2: Color.lerp(spo2, other.spo2, t)!,
    );
  }
}

class OpenAirTheme {
  static ThemeData dark() => _build(Brightness.dark, OpenAirColors.dark);

  static ThemeData light() => _build(Brightness.light, OpenAirColors.light);

  static ThemeData _build(Brightness brightness, OpenAirColors colors) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.green,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: colors.greenSoft,
        onSecondary: colors.textPrimary,
        error: colors.heart,
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.textPrimary,
      ),
    );

    final textTheme = GoogleFonts.dmSansTextTheme(base.textTheme).apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    );

    return base.copyWith(
      extensions: [colors],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.green.withValues(alpha: isDark ? 0.22 : 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.green : colors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.green : colors.textMuted,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
      ),
      dividerColor: colors.border,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? colors.green : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? colors.green.withValues(alpha: 0.35)
              : null,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.green,
          foregroundColor: isDark ? Colors.black : Colors.white,
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.green, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: GoogleFonts.dmSans(color: colors.textPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.green,
        foregroundColor: isDark ? Colors.black : Colors.white,
      ),
    );
  }
}
