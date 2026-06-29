import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.poppins().fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryDarkGreen,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.light().textTheme,
      ),
      scaffoldBackgroundColor: AppColors.softWhiteBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.softWhiteBackground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  // Text Styles
  static TextStyle get titleLarge => GoogleFonts.poppins(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      color: AppColors.textPrimary,
      decoration: TextDecoration.none,
      );

  static TextStyle get titleMedium => GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
      decoration: TextDecoration.none,
      );

  static TextStyle get subtitleRegular => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
      decoration: TextDecoration.none,
        letterSpacing: 0.5,
      );

  static TextStyle get subtitleSmall => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w400,
      color: AppColors.textLight,
      decoration: TextDecoration.none,
        letterSpacing: 0.3,
      );

  static TextStyle get buttonText => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      color: AppColors.pureWhite,
      decoration: TextDecoration.none,
        letterSpacing: 0.5,
      );

  static TextStyle get captionText => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      color: AppColors.textLight,
      decoration: TextDecoration.none,
        letterSpacing: 0.3,
      );
}
