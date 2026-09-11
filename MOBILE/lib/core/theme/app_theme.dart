import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary500,
        onPrimary: AppColors.ink0,
        primaryContainer: AppColors.primary100,
        onPrimaryContainer: AppColors.primary600,
        secondary: AppColors.accent500,
        onSecondary: AppColors.ink0,
        secondaryContainer: AppColors.accent100,
        onSecondaryContainer: AppColors.ink900,
        error: AppColors.danger500,
        onError: AppColors.ink0,
        surface: AppColors.ink0,
        onSurface: AppColors.ink900,
        surfaceContainerHighest: AppColors.ink100,
        outline: AppColors.ink300,
        outlineVariant: AppColors.ink100,
      ),
      scaffoldBackgroundColor: AppColors.ink0,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: AppTypography.displayLg,
        headlineLarge: AppTypography.h1,
        headlineMedium: AppTypography.h2,
        headlineSmall: AppTypography.h3,
        bodyLarge: AppTypography.bodyLg,
        bodyMedium: AppTypography.bodyMd,
        bodySmall: AppTypography.bodySm,
        labelSmall: AppTypography.label,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ink0,
        foregroundColor: AppColors.ink900,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: AppTypography.h2.copyWith(color: AppColors.ink900),
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary500,
          foregroundColor: AppColors.ink0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          textStyle: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary500,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.primary500, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.ink100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s16,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.ink300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.ink300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.primary500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.danger500),
        ),
        hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.ink500),
        labelStyle: AppTypography.bodyMd.copyWith(color: AppColors.ink700),
      ),
      cardTheme: CardThemeData(
        color: AppColors.ink0,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: const BorderSide(color: AppColors.ink300),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.ink300,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.ink0,
        modalBackgroundColor: AppColors.ink0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink900,
        contentTextStyle: AppTypography.bodyMd.copyWith(color: AppColors.ink0),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return base;
  }
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary500,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: GoogleFonts.interTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: AppTypography.h2.copyWith(color: scheme.onSurface),
        centerTitle: false,
      ),
    );
  }
}