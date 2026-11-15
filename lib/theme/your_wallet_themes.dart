
import 'package:flutter/material.dart';

import 'app_colors.dart';

class YourWalletThemes {
  YourWalletThemes._();

  static final ThemeData light = _build(
    Brightness.light,
  );

  static final ThemeData dark = _build(
    Brightness.dark,
  );

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );

    final background = isDark
        ? const Color(0xFF111827)
        : const Color(0xFFF6F8FC);

    final surface = isDark
        ? const Color(0xFF1F2937)
        : Colors.white;

    final outline = isDark
        ? const Color(0xFF4B5563)
        : const Color(0xFFE2E8F0);

    final textColor = isDark
        ? const Color(0xFFF9FAFB)
        : const Color(0xFF111827);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme.copyWith(
        surface: surface,
        onSurface: textColor,
      ),

      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: background,

      // ======================================
      // APP BAR
      // ======================================

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textColor,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      // ======================================
      // TEXT
      // ======================================

      textTheme: ThemeData(
        brightness: brightness,
      ).textTheme.apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),

      // ======================================
      // INPUT
      // ======================================

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),

      // ======================================
      // BUTTON
      // ======================================

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,

          minimumSize: const Size(0, 50),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,

          side: BorderSide(color: outline),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // ======================================
      // BOTTOM NAVIGATION
      // ======================================

      bottomNavigationBarTheme:
      BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: isDark
            ? Colors.white60
            : Colors.black54,
        type: BottomNavigationBarType.fixed,
      ),

      // ======================================
      // DIVIDER / ICON
      // ======================================

      dividerColor: outline,

      iconTheme: IconThemeData(
        color: textColor,
      ),
    );
  }
}
