import 'package:flutter/material.dart';

class OwnerPalette {
  static const blue = Color(0xFF204ED8);
  static const vividBlue = Color(0xFFA8BFFF);
  static const lightBackground = Color(0xFFF4F6FB);
  static const darkBackground = Color(0xFF0C1422);
  static const lightSurface = Color(0xFFFFFFFF);
  static const darkSurface = Color(0xFF142033);
  static const lightRaised = Color(0xFFEDF1F8);
  static const darkRaised = Color(0xFF1A2940);
  static const lightText = Color(0xFF13203A);
  static const darkText = Color(0xFFEDF4FF);
  static const lightMuted = Color(0xFF4C5D74);
  static const darkMuted = Color(0xFFA8B8CD);
  static const lightLine = Color(0xFFDCE4EF);
  static const darkLine = Color(0xFF2A3B54);
  static const lightSelection = Color(0xFFE8EDFF);
  static const darkSelection = Color(0xFF223664);
  static const revenueSurface = Color(0xFF14284E);
  static const revenueText = Color(0xFFF7FAFF);
  static const revenueMuted = Color(0xFFBDCCE8);
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
  static Color border(BuildContext context) =>
      isDark(context) ? darkLine : lightLine;
  static Color selection(BuildContext context) =>
      isDark(context) ? darkSelection : lightSelection;

  static ThemeData light = create(Brightness.light);
  static ThemeData dark = create(Brightness.dark);

  static ThemeData create(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final ink = dark ? darkText : lightText;
    final surface = dark ? darkSurface : lightSurface;
    final line = dark ? darkLine : lightLine;
    final selection = dark ? darkSelection : lightSelection;
    final primary = dark ? vividBlue : blue;
    final muted = dark ? darkMuted : lightMuted;
    final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: dark ? darkBackground : lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: blue,
        brightness: brightness,
        surface: surface,
        onSurface: ink,
        onSurfaceVariant: muted,
        primary: primary,
        onPrimary: dark ? revenueSurface : Colors.white,
        secondaryContainer: selection,
        onSecondaryContainer: primary,
        outlineVariant: line,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: surface,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerColor: line,
      chipTheme: ChipThemeData(
        side: BorderSide(color: line),
        shape: controlShape,
        backgroundColor: surface,
        selectedColor: selection,
        secondarySelectedColor: selection,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: controlShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: controlShape),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: line),
        ),
      ),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
    );
  }
}
