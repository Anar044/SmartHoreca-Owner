import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OwnerPalette {
  static const blue = Color(0xFF2563EB);
  static const vividBlue = Color(0xFF3B82F6);
  static const lightBackground = Color(0xFFF3F6FC);
  static const darkBackground = Color(0xFF0D1728);
  static const lightSurface = Color(0xFFFFFFFF);
  static const darkSurface = Color(0xFF19283F);
  static const lightRaised = Color(0xFFE9F0FA);
  static const darkRaised = Color(0xFF233650);
  static const lightText = Color(0xFF132844);
  static const darkText = Color(0xFFF6F9FF);
  static const lightMuted = Color(0xFF64748B);
  static const darkMuted = Color(0xFFA8BAD0);
  static const green = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color background(BuildContext context) =>
      isDark(context) ? darkBackground : lightBackground;
  static Color surface(BuildContext context) =>
      isDark(context) ? darkSurface : lightSurface;
  static Color raised(BuildContext context) =>
      isDark(context) ? darkRaised : lightRaised;
  static Color text(BuildContext context) =>
      isDark(context) ? darkText : lightText;
  static Color muted(BuildContext context) =>
      isDark(context) ? darkMuted : lightMuted;
  static Color accent(BuildContext context) =>
      isDark(context) ? vividBlue : blue;

  static ThemeData light = create(Brightness.light);
  static ThemeData dark = create(Brightness.dark);

  static ThemeData create(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final ink = dark ? darkText : lightText;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: dark ? darkBackground : lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: blue,
        brightness: brightness,
        surface: dark ? darkBackground : lightBackground,
        primary: dark ? vividBlue : blue,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: dark ? darkBackground : lightBackground,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerColor: dark ? const Color(0xFF2F425A) : const Color(0xFFE2E9F2),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? darkSurface : lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(
        ThemeData(brightness: brightness).textTheme.apply(
          bodyColor: ink,
          displayColor: ink,
        ),
      ),
    );
  }
}
