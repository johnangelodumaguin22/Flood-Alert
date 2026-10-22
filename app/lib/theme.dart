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

  // Dashboard design palette. river/water above stay as they are: the logo uses them.
  static const navy = Color(0xFF111A2C);
  static const blue = Color(0xFF1D5FD6);
  static const blueBg = Color(0xFFEAF1FD);
  static const page = Color(0xFFF6F8FB);
  static const border = Color(0xFFE2E8F0);
  static const slate = Color(0xFF64748B);
  static const text = Color(0xFF0F172A);
  static const okText = Color(0xFF15803D);
  static const okBg = Color(0xFFE7F7EC);
  static const okEdge = Color(0xFF9ED9B1);
  static const amberText = Color(0xFFD97706);
  static const amberBg = Color(0xFFFEF3C7);
  static const amberEdge = Color(0xFFF6D57A);
  static const red = Color(0xFFDC2626);
  static const redBg = Color(0xFFFDE2E2);
  static const redEdge = Color(0xFFF4A5A5);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.river, primary: AppColors.river, error: AppColors.crit),
    scaffoldBackgroundColor: AppColors.page,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.border, width: 1.5),
  );
  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.blue, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.blue,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.blue,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}
