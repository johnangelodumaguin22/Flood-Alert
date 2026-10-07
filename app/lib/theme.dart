import 'package:flutter/material.dart';

class AppColors {
  static const river = Color(0xFF0E3B43);
  static const water = Color(0xFF2E7FA0);
  static const silt = Color(0xFFEEF1EF);
  static const line = Color(0xFFD5DCDA);
  static const muted = Color(0xFF5B6B70);
  static const ink = Color(0xFF132227);
  static const safe = Color(0xFF2F8F5B);
  static const safeBg = Color(0xFFE3F2E9);
  static const warn = Color(0xFFB97F00);
  static const warnFill = Color(0xFFE5A712);
  static const warnBg = Color(0xFFFDF3D8);
  static const crit = Color(0xFFC8322B);
  static const critBg = Color(0xFFFBE4E2);
  static const off = Color(0xFF7A8588);
  static const offBg = Color(0xFFECEEEE);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.river, primary: AppColors.river, error: AppColors.crit),
    scaffoldBackgroundColor: AppColors.silt,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.line, width: 1.5),
  );
  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.water, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.river,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.water,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}
