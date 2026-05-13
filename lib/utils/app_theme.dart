import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF07090D);
  static const surface = Color(0xFF10151D);
  static const surfaceHigh = Color(0xFF171D27);
  static const glass = Color(0xB3141A22);
  static const border = Color(0x26FFFFFF);
  static const text = Color(0xFFF4F7F8);
  static const muted = Color(0xFF8E99A8);
  static const blue = Color(0xFF3EA2FF);
  static const green = Color(0xFF34F28A);
  static const red = Color(0xFFFF4D5D);
  static const yellow = Color(0xFFFFC247);
  static const purple = Color(0xFF8F7CFF);
}

ThemeData buildYezdiTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.green,
      secondary: AppColors.blue,
      surface: AppColors.surface,
      error: AppColors.red,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.text,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF111823),
      hintStyle: const TextStyle(color: AppColors.muted),
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
        borderSide: const BorderSide(color: AppColors.green, width: 1.2),
      ),
    ),
  );
}
