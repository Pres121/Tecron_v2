import "package:flutter/material.dart";

/// Tecron's palette: white surfaces, a single confident green as the brand
/// color, warm dark text (not pure black). "Verified" results reuse the
/// brand green; "predicted" results get a neutral gray so the one color
/// that means something (green = confirmed) never gets diluted.
class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF6FAF7);
  static const surfaceBorder = Color(0xFFDCE8E1);

  static const primary = Color(0xFF1FAA59);
  static const primaryDark = Color(0xFF116938);
  static const primarySoft = Color(0xFFE5F7EC);

  static const textPrimary = Color(0xFF14201A);
  static const textSecondary = Color(0xFF5B6B62);
  static const textFaint = Color(0xFF94A79C);

  static const neutral = Color(0xFF7A8B82);
  static const neutralSoft = Color(0xFFF0F3F1);

  static const error = Color(0xFFD64545);
  static const errorSoft = Color(0xFFFBEAEA);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      fontFamily: "Roboto",
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
      ),
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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.primary : Colors.transparent,
        ),
      ),
    );
  }
}
