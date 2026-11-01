// SwimTrack design system - all colors, text styles, and ThemeData.
// Every widget in the app must use these constants. Never hardcode hex values.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// All brand colors for the SwimTrack app.
/// Source of truth - mirrors the Figma design system exactly.
class SwimTrackColors {
  SwimTrackColors._();

  static const Color primary       = Color(0xFF0077B6);
  static const Color secondary     = Color(0xFF00B4D8);
  static const Color background    = Color(0xFFF8FAFE);
  static const Color card          = Color(0xFFFFFFFF);
  static const Color dark          = Color(0xFF1A1A2E);
  static const Color textPrimary   = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF4A4A68);
  static const Color textHint      = Color(0xFF8E8EA0);
  static const Color good          = Color(0xFF2ECC71);
  static const Color bad           = Color(0xFFE74C3C);
  static const Color neutral       = Color(0xFFF39C12);
  static const Color divider       = Color(0xFFE8EDF2);
  static const Color gradientEnd   = Color(0xFF005A8E);
}

/// All text styles for the SwimTrack app.
/// Uses Poppins for headings/numbers, Inter for body/labels.
class SwimTrackTextStyles {
  SwimTrackTextStyles._();

  /// 64px Poppins Bold - dominant live session number (stroke count).
  static TextStyle hugeNumber({Color color = SwimTrackColors.dark}) =>
      GoogleFonts.poppins(
        fontSize: 64,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.0,
      );

  /// 48px Poppins Bold - large metric values.
  static TextStyle bigNumber({Color color = SwimTrackColors.dark}) =>
      GoogleFonts.poppins(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.0,
      );

  /// 32px Poppins Bold - logo / app name on login screen.
  static TextStyle logoTitle({Color color = Colors.white}) =>
      GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
      );

  /// 24px Poppins SemiBold - screen headings.
  static TextStyle screenTitle({Color color = SwimTrackColors.dark}) =>
      GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// 18px Poppins SemiBold - section headers, MetricCard values.
  static TextStyle sectionHeader({Color color = SwimTrackColors.dark}) =>
      GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// 16px Inter SemiBold - card titles, important labels.
  static TextStyle cardTitle({Color color = SwimTrackColors.dark}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// 14px Inter Regular - body text, descriptions.
  static TextStyle body({Color color = SwimTrackColors.textSecondary}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.43,
      );

  /// 12px Inter Regular - labels, units, secondary info.
  static TextStyle label({Color color = SwimTrackColors.textHint}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.33,
      );

  /// 10px Inter Regular - timestamps, hints, tiny annotations.
  static TextStyle tiny({Color color = SwimTrackColors.textHint}) =>
      GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
      );
}

/// Returns the app-wide [ThemeData] for SwimTrack.
/// Call once in [MaterialApp.theme].
ThemeData swimTrackTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: SwimTrackColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: SwimTrackColors.primary,
      primary: SwimTrackColors.primary,
      surface: SwimTrackColors.card,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: SwimTrackColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: SwimTrackTextStyles.screenTitle(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SwimTrackColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        shadowColor: SwimTrackColors.primary.withValues(alpha: 0.3),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SwimTrackColors.primary,
        minimumSize: const Size(double.infinity, 48),
        side: const BorderSide(color: SwimTrackColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    // ✅ FIX: Use CardThemeData (not CardTheme) for Material 3 compatibility
    cardTheme: CardThemeData(
      color: SwimTrackColors.card,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SwimTrackColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SwimTrackColors.divider, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SwimTrackColors.divider, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SwimTrackColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SwimTrackColors.bad, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SwimTrackColors.bad, width: 1.5),
      ),
      hintStyle: SwimTrackTextStyles.body(color: SwimTrackColors.textHint),
      labelStyle: SwimTrackTextStyles.label(color: SwimTrackColors.textSecondary),
    ),
    dividerTheme: const DividerThemeData(
      color: SwimTrackColors.divider,
      thickness: 1,
      space: 0,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : SwimTrackColors.textHint,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? SwimTrackColors.primary
            : SwimTrackColors.divider,
      ),
    ),
  );
}