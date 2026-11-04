import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF6366F1); // Indigo accent
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color accent = Color(0xFF10B981); // Emerald
  static const Color recordingRed = Color(0xFFEF4444); // Studio Record Red
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color cardDark = Color(0xFF1E293B); // Slate 800
  static const Color surfaceDark = Color(0xFF334155); // Slate 700
  static const Color inputFill = Color(0xFF1A2333);
  static const Color border = Color(0xFF2E3E55);
  static const Color textPrimary = Colors.white;
  static const Color textBody = Color(0xFFE2E8F0); // Slate 200
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textSubtle = Color(0xFF64748B); // Slate 500
  static const Color guideAmber = Color(0xFFFBBF24); // Amber 400
  static const Color hudBackground = Color(0xE60F172A);

  // Brand: deep ink with champagne gold.
  static const Color ink = Color(0xFF0A0D16);
  static const Color gold = Color(0xFFCFB07A);
  static const Color goldLight = Color(0xFFEAD7AE);
  static const Color goldDeep = Color(0xFFA8864F);

  static const double radiusSmall = 10;
  static const double radiusMedium = 14;
  static const double radiusLarge = 20;

  static final RoundedRectangleBorder _mediumShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radiusMedium),
  );

  static const String fontFamily = 'Montserrat';

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: fontFamily,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      error: recordingRed,
      surface: cardDark,
      onSurface: textPrimary,
      outline: border,
    ),
    scaffoldBackgroundColor: darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: fontFamily, 
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0.1,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: _mediumShape,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: _mediumShape,
        textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF3B4D66)),
        shape: _mediumShape,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primaryLight),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 15),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
      titleTextStyle: const TextStyle(fontFamily: fontFamily, 
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      contentTextStyle: const TextStyle(fontFamily: fontFamily, fontSize: 14, color: textMuted, height: 1.4),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: cardDark,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cardDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        side: const BorderSide(color: border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: surfaceDark,
      contentTextStyle: const TextStyle(fontFamily: fontFamily, color: textPrimary, fontSize: 14),
      actionTextColor: primaryLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: primary,
      thumbColor: primaryLight,
      inactiveTrackColor: surfaceDark,
      trackHeight: 4,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: darkBackground,
      selectedColor: primary,
      side: const BorderSide(color: surfaceDark),
      labelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(fontFamily: fontFamily, color: textPrimary, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(fontFamily: fontFamily, color: textSubtle),
    ),
  );
}
