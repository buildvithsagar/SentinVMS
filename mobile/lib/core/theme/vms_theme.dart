import 'package:flutter/material.dart';

abstract final class VmsColors {
  static const canvas = Color(0xFF07110F);
  static const canvasRaised = Color(0xFF091714);
  static const surface = Color(0xFF0D1B18);
  static const surfaceHigh = Color(0xFF132622);
  static const surfaceHighest = Color(0xFF19302B);
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
  static const scrim = Color(0xB3000000);
}

abstract final class VmsSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
}

abstract final class VmsRadii {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double pill = 999;
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
      disabledColor: VmsColors.textMuted.withValues(alpha: 0.45),
      splashColor: VmsColors.primary.withValues(alpha: 0.08),
      highlightColor: VmsColors.primary.withValues(alpha: 0.05),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
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
        labelLarge: TextStyle(
          color: VmsColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
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
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VmsColors.primary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VmsRadii.sm),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: VmsColors.textSecondary,
          minimumSize: const Size(48, 48),
          iconSize: 22,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VmsRadii.sm),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: VmsColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VmsRadii.md),
          side: const BorderSide(color: VmsColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: VmsColors.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: VmsColors.textSecondary,
        textColor: VmsColors.textPrimary,
        subtitleTextStyle: TextStyle(
          color: VmsColors.textMuted,
          fontSize: 12,
          height: 1.35,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        minTileHeight: 52,
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: const WidgetStatePropertyAll(VmsColors.surface),
        elevation: const WidgetStatePropertyAll(0),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(color: VmsColors.textPrimary),
        ),
        hintStyle: const WidgetStatePropertyAll(
          TextStyle(color: VmsColors.textMuted),
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: VmsColors.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VmsRadii.md),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? VmsColors.primary
              : Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Color(0xFF03201B)),
        side: const BorderSide(color: VmsColors.textMuted, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VmsRadii.xs),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? const Color(0xFF03201B)
              : VmsColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? VmsColors.primary
              : VmsColors.surfaceHighest;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(VmsColors.border),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: VmsColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VmsRadii.md),
          side: const BorderSide(color: VmsColors.border),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: VmsColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: VmsColors.surfaceHigh,
        headerForegroundColor: VmsColors.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VmsRadii.lg),
          side: const BorderSide(color: VmsColors.border),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: VmsColors.surface,
        hourMinuteColor: VmsColors.surfaceHigh,
        hourMinuteTextColor: VmsColors.textPrimary,
        dialBackgroundColor: VmsColors.surfaceHigh,
        dialHandColor: VmsColors.primary,
        entryModeIconColor: VmsColors.textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VmsRadii.lg),
          side: const BorderSide(color: VmsColors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: VmsColors.surface,
        indicatorColor: VmsColors.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? VmsColors.primary : VmsColors.textMuted,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? VmsColors.primary : VmsColors.textSecondary,
            size: 22,
          );
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: VmsColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: VmsColors.scrim,
        showDragHandle: true,
        dragHandleColor: VmsColors.textMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(VmsRadii.lg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: VmsColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VmsRadii.lg),
          side: const BorderSide(color: VmsColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: VmsColors.surfaceHigh,
        selectedColor: VmsColors.primary.withValues(alpha: 0.14),
        side: const BorderSide(color: VmsColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VmsRadii.pill),
        ),
        labelStyle: const TextStyle(
          color: VmsColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: VmsColors.primary,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: VmsColors.surfaceHigh,
        contentTextStyle: TextStyle(color: VmsColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(VmsRadii.sm)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: VmsColors.surfaceHigh,
          borderRadius: BorderRadius.circular(VmsRadii.xs),
          border: Border.all(color: VmsColors.border),
        ),
        textStyle: const TextStyle(color: VmsColors.textPrimary, fontSize: 12),
      ),
    );
  }
}
