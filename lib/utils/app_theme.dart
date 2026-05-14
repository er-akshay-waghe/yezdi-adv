import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF050608);
  static const surface = Color(0xFF101216);
  static const surfaceHigh = Color(0xFF191D23);
  static const glass = Color(0xB312151A);
  static const border = Color(0x30FFFFFF);
  static const text = Color(0xFFF7F3EC);
  static const muted = Color(0xFFA6A093);
  static const orange = Color(0xFFE86E1C);
  static const amber = Color(0xFFFFB33B);
  static const blue = Color(0xFF27B8FF);
  static const green = Color(0xFF34F28A);
  static const red = Color(0xFFFF4D5D);
  static const yellow = Color(0xFFFFC247);
  static const purple = Color(0xFF8F7CFF);

  static const adventureGradient = [
    Color(0xFFE86E1C),
    Color(0xFFFFB33B),
  ];

  static const nightGradient = [
    Color(0xFF050608),
    Color(0xFF101216),
    Color(0xFF1A1511),
  ];
}

ThemeData buildYezdiTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.orange,
      secondary: AppColors.blue,
      surface: AppColors.surface,
      error: AppColors.red,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.text,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    ),
    textTheme: base.textTheme
        .apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        )
        .copyWith(
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF111419),
      hintStyle: const TextStyle(color: AppColors.muted),
      labelStyle: const TextStyle(color: AppColors.muted),
      prefixIconColor: AppColors.amber,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.amber, width: 1.2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface.withValues(alpha: 0.88),
      indicatorColor: AppColors.orange.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.amber
              : AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.amber
              : AppColors.muted,
        ),
      ),
    ),
  );
}
