import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EduColors {
  static const Color royalBlue = Color(0xFF1A56DB);
  static const Color royalBlueDark = Color(0xFF1243AF);
  static const Color royalBlueLight = Color(0xFFD6E4FF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF8F9FC);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color surface = Color(0xFFF1F5F9);

  // Dark theme colors
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkCardBorder = Color(0xFF334155);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkTextMedium = Color(0xFF94A3B8);
  static const Color darkTextLight = Color(0xFF64748B);
  static const Color darkAppBar = Color(0xFF1E293B);
  static const Color darkInputFill = Color(0xFF334155);
}

class EduTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.light().textTheme,
      ),
      colorScheme: ColorScheme.light(
        primary: EduColors.royalBlue,
        onPrimary: EduColors.white,
        primaryContainer: EduColors.royalBlueLight,
        secondary: EduColors.success,
        onSecondary: EduColors.white,
        surface: EduColors.offWhite,
        onSurface: EduColors.textDark,
        outline: EduColors.cardBorder,
      ),
      scaffoldBackgroundColor: EduColors.offWhite,
      appBarTheme: AppBarTheme(
        backgroundColor: EduColors.white,
        foregroundColor: EduColors.textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: EduColors.textDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EduColors.royalBlue,
          foregroundColor: EduColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: EduColors.royalBlue,
          side: const BorderSide(color: EduColors.royalBlue),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: EduColors.cardBorder),
        ),
        color: EduColors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EduColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EduColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EduColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EduColors.royalBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EduColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.poppins(color: EduColors.textMedium),
        hintStyle: GoogleFonts.poppins(color: EduColors.textLight),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: EduColors.white,
        selectedItemColor: EduColors.royalBlue,
        unselectedItemColor: EduColors.textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: EduColors.cardBorder,
        thickness: 1,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.dark().textTheme,
      ),
      colorScheme: ColorScheme.dark(
        primary: EduColors.royalBlue,
        onPrimary: EduColors.white,
        primaryContainer: EduColors.royalBlueDark,
        secondary: EduColors.success,
        onSecondary: EduColors.white,
        surface: EduColors.darkSurface,
        onSurface: EduColors.darkText,
        outline: EduColors.darkCardBorder,
      ),
      scaffoldBackgroundColor: EduColors.darkBg,
      appBarTheme: AppBarTheme(
        backgroundColor: EduColors.darkAppBar,
        foregroundColor: EduColors.darkText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: EduColors.darkText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EduColors.royalBlue,
          foregroundColor: EduColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: EduColors.royalBlue,
          side: const BorderSide(color: EduColors.royalBlue),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: EduColors.darkCardBorder),
        ),
        color: EduColors.darkCard,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EduColors.darkInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EduColors.darkCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EduColors.darkCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EduColors.royalBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EduColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.poppins(color: EduColors.darkTextMedium),
        hintStyle: GoogleFonts.poppins(color: EduColors.darkTextLight),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: EduColors.darkAppBar,
        selectedItemColor: EduColors.royalBlue,
        unselectedItemColor: EduColors.darkTextLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: EduColors.darkCardBorder,
        thickness: 1,
      ),
    );
  }
}
