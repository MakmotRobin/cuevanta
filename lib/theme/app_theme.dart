import 'package:flutter/material.dart';

/// Cuevanta's visual language: deep ink surfaces, champagne-gold accents,
/// warm white type in Montserrat, hairline borders and generous spacing.
class AppTheme {
  // Brand
  static const Color ink = Color(0xFF0A0D16);
  static const Color gold = Color(0xFFCFB07A);
  static const Color goldLight = Color(0xFFEAD7AE);
  static const Color goldDeep = Color(0xFFA8864F);
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldLight, gold, goldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Semantic roles
  static const Color primary = gold;
  static const Color primaryLight = goldLight;
  static const Color accent = gold;
  static const Color recordingRed = Color(0xFFE5484D);
  static const Color darkBackground = ink;
  static const Color cardDark = Color(0xFF11151F); // resting surface
  static const Color surfaceDark = Color(0xFF1A1F2C); // raised surface
  static const Color inputFill = Color(0xFF11151F);
  static const Color border = Color(0xFF222838); // hairline
  static const Color hudBackground = Color(0xEB0A0D16);

  // Type
  static const Color textPrimary = Color(0xFFF4F1EA); // warm white
  static const Color textBody = Color(0xFFD9D6CF);
  static const Color textMuted = Color(0xFF8E93A3);
  static const Color textSubtle = Color(0xFF5E6475);

  static const double radiusSmall = 10;
  static const double radiusMedium = 14;
  static const double radiusLarge = 20;

  static const String fontFamily = 'Montserrat';

  /// Small uppercase label used for eyebrows and section titles.
  static const TextStyle eyebrow = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 3,
    color: gold,
  );

  static final RoundedRectangleBorder _mediumShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radiusMedium),
  );

  static const TextStyle _buttonLabel = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 13,
    letterSpacing: 1.6,
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: fontFamily,
    colorScheme: const ColorScheme.dark(
      primary: gold,
      onPrimary: ink,
      secondary: gold,
      onSecondary: ink,
      secondaryContainer: surfaceDark,
      onSecondaryContainer: goldLight,
      error: recordingRed,
      surface: cardDark,
      onSurface: textPrimary,
      onSurfaceVariant: textMuted,
      outline: border,
      outlineVariant: border,
    ),
    scaffoldBackgroundColor: ink,
    canvasColor: ink,
    appBarTheme: const AppBarTheme(
      backgroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: textBody, size: 22),
      actionsIconTheme: IconThemeData(color: textBody, size: 22),
    ),
    iconTheme: const IconThemeData(color: textBody),
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
        backgroundColor: gold,
        foregroundColor: ink,
        shape: _mediumShape,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: _buttonLabel,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: ink,
        shape: _mediumShape,
        textStyle: _buttonLabel,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: BorderSide(color: gold.withValues(alpha: 0.45)),
        shape: _mediumShape,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        textStyle: _buttonLabel,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: gold,
        textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: textBody),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: gold,
      foregroundColor: ink,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: _buttonLabel,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
        side: const BorderSide(color: border),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      contentTextStyle: const TextStyle(fontFamily: fontFamily, fontSize: 14, color: textMuted, height: 1.5),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: cardDark,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surfaceDark,
      surfaceTintColor: Colors.transparent,
      textStyle: const TextStyle(fontFamily: fontFamily, color: textPrimary, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        side: const BorderSide(color: border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: surfaceDark,
      contentTextStyle: const TextStyle(fontFamily: fontFamily, color: textPrimary, fontSize: 14),
      actionTextColor: gold,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        side: const BorderSide(color: border),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: gold,
      thumbColor: goldLight,
      inactiveTrackColor: border,
      overlayColor: gold.withValues(alpha: 0.12),
      valueIndicatorColor: surfaceDark,
      trackHeight: 2,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? ink : textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? gold : surfaceDark,
      ),
      trackOutlineColor: WidgetStateProperty.all(border),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? gold : Colors.transparent,
      ),
      checkColor: WidgetStateProperty.all(ink),
      side: const BorderSide(color: textSubtle, width: 1.5),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: cardDark,
      selectedColor: gold,
      side: const BorderSide(color: border),
      labelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, color: textBody),
      secondaryLabelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, color: ink),
      checkmarkColor: ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: gold),
    dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      textStyle: const TextStyle(fontFamily: fontFamily, color: textPrimary, fontSize: 12),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: gold,
      selectionColor: gold.withValues(alpha: 0.3),
      selectionHandleColor: gold,
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
        borderSide: BorderSide(color: gold.withValues(alpha: 0.7), width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(fontFamily: fontFamily, color: textSubtle),
      prefixIconColor: textMuted,
      suffixIconColor: textMuted,
    ),
  );
}
