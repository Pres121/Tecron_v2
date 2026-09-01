import "package:flutter/material.dart";

/// Tecron palette and dark theme.
/// Keep a single brand green (`primary`) and high-contrast white text
/// on very dark surfaces so elements remain visible.
class AppColors {
  // Core surface and background (very dark for a modern look)
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF0B0B0B);
  static const surfaceBorder = Color(0xFF1F1F1F);

  // Brand
  static const primary = Color(0xFF1FAA59);
  static const primaryDark = Color(0xFF0E8A45);
  static const primarySoft = Color(0xFF08381E);

  // Text and neutrals
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFBFDCC8);
  static const textFaint = Color(0xFF6F8A78);

  // Accents / feedback
  static const neutral = Color(0xFF7A8B82);
  static const neutralSoft = Color(0xFFF0F3F1);

  static const error = Color(0xFFD64545);
  static const errorSoft = Color(0xFFFBEAEA);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
        titleLarge: TextStyle(color: AppColors.textPrimary),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 15),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.surfaceBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
      ),

      // App bar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      // Bottom nav
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textFaint,
        showUnselectedLabels: true,
      ),

      // Icons and general visuals
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      dividerColor: AppColors.surfaceBorder,

      // Feedback elements
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),

      // Floating action button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
      ),

      // Switches / toggles
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected) ? AppColors.primary : Colors.white24;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected) ? AppColors.primary.withValues(alpha: 0.4) : Colors.white24;
        }),
      ),

      // Checkboxes
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected) ? AppColors.primary : Colors.white24;
        }),
        checkColor: WidgetStateProperty.all(AppColors.background),
      ),

      // Tooltips and list tiles
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.all(Radius.circular(4))),
        textStyle: TextStyle(color: AppColors.textPrimary, fontSize: 12),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: AppColors.surface,
        textColor: AppColors.textPrimary,
        iconColor: AppColors.textPrimary,
      ),
    );
  }
  // Backwards-compatible alias: repo previously referenced `AppTheme.light`.
  static ThemeData get light => dark;
}
