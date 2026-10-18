import 'package:flutter/material.dart';

abstract final class VmsColors {
  static const canvas = Color(0xFF07110F);
  static const surface = Color(0xFF0D1B18);
  static const surfaceHigh = Color(0xFF132622);
  static const border = Color(0xFF203B35);
  static const primary = Color(0xFF2DD4BF);
  static const primaryStrong = Color(0xFF14B8A6);
  static const information = Color(0xFF60A5FA);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
  static const textPrimary = Color(0xFFF1F5F4);
  static const textSecondary = Color(0xFF9FB3AE);
  static const textMuted = Color(0xFF647A75);
}

// ignore: avoid_classes_with_only_static_members
abstract final class VmsTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: VmsColors.primary,
      secondary: VmsColors.information,
      error: VmsColors.danger,
      surface: VmsColors.surface,
      onPrimary: Color(0xFF03201B),
      onSurface: VmsColors.textPrimary,
    );
    const inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: VmsColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: VmsColors.canvas,
      canvasColor: VmsColors.canvas,
      cardColor: VmsColors.surface,
      dividerColor: VmsColors.border,
      splashColor: VmsColors.primary.withValues(alpha: 0.08),
      highlightColor: VmsColors.primary.withValues(alpha: 0.05),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: VmsColors.canvas,
        foregroundColor: VmsColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: VmsColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: VmsColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: VmsColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: VmsColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: VmsColors.textPrimary, height: 1.45),
        bodyMedium: TextStyle(color: VmsColors.textSecondary, height: 1.4),
        bodySmall: TextStyle(color: VmsColors.textMuted, height: 1.35),
        labelLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: VmsColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: VmsColors.textSecondary),
        hintStyle: TextStyle(color: VmsColors.textMuted),
        prefixIconColor: VmsColors.textSecondary,
        suffixIconColor: VmsColors.textSecondary,
        enabledBorder: inputBorder,
        border: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: VmsColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: VmsColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: VmsColors.danger, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VmsColors.primary,
          foregroundColor: const Color(0xFF03201B),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VmsColors.textPrimary,
          minimumSize: const Size(64, 52),
          side: const BorderSide(color: VmsColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: VmsColors.primary,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: VmsColors.surfaceHigh,
        contentTextStyle: TextStyle(color: VmsColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
