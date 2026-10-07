import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0A0612);
  static const bgAlt = Color(0xFF120A1F);
  static const card = Color(0xFF1A0F2E);
  static const cardAlt = Color(0xFF231441);

  static const pink = Color(0xFFFF1493);
  static const pinkLight = Color(0xFFFF4DAD);
  static const purple = Color(0xFF9C27B0);
  static const purpleDeep = Color(0xFF6A1B9A);
  static const violet = Color(0xFF7B2FF7);

  static const success = Color(0xFF00E676);
  static const warning = Color(0xFFFFC107);
  static const danger = Color(0xFFFF3B5C);
  static const gold = Color(0xFFFFD54F);

  static const text = Color(0xFFFFFFFF);
  static const textDim = Color(0xFFB8A8D6);
  static const textMute = Color(0xFF7A6B96);

  static const pinkGradient = LinearGradient(
    colors: [Color(0xFFFF1493), Color(0xFF9C27B0)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const pinkPurpleGradient = LinearGradient(
    colors: [Color(0xFFFF1493), Color(0xFF7B2FF7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const purpleGlow = LinearGradient(
    colors: [Color(0xFF9C27B0), Color(0xFF3D1568)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.pink,
        secondary: AppColors.purple,
        surface: AppColors.card,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.text,
      ),
      cardColor: AppColors.card,
      dividerColor: AppColors.cardAlt,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.text),
        bodyMedium: TextStyle(color: AppColors.text),
        bodySmall: TextStyle(color: AppColors.textDim),
        titleLarge: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cardAlt, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.pink, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textDim),
        hintStyle: const TextStyle(color: AppColors.textMute),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.pink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.cardAlt,
        contentTextStyle: TextStyle(color: AppColors.text),
      ),
    );
  }

  static ThemeData light() => dark();
}
