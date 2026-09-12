import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const cream = Color(0xFFFBF4EC);
  static const paper = Color(0xFFFFFAF4);
  static const paper2 = Color(0xFFF6EADF);
  static const ink = Color(0xFF241D18);
  static const muted = Color(0xFF6D6259);
  static const soft = Color(0xFFE8DDD2);

  static const green = Color(0xFF007437);
  static const green2 = Color(0xFF0A8A46);
  static const greenDark = Color(0xFF005C2C);
  static const mint = Color(0xFFEAF8EB);
  static const mint2 = Color(0xFFBCEEC8);

  static const amber = Color(0xFFF4A000);
  static const amberBg = Color(0xFFFFF6D7);

  static const red = Color(0xFFDB2C2C);
  static const redBg = Color(0xFFFFE5E1);

  static const soil = Color(0xFF5E432D);
  static const blue = Color(0xFF2867A5);

  static const pinActive = Color(0xFF2F64FF);
}

class AppRadius {
  AppRadius._();

  static const card = 22.0;
  static const cardSmall = 18.0;
  static const button = 16.0;
  static const input = 14.0;
  static const pill = 999.0;
}

class AppShadows {
  AppShadows._();

  static const soft = [
    BoxShadow(color: Color(0x172D2115), blurRadius: 20, offset: Offset(0, 8)),
  ];
}

class AppTheme {
  AppTheme._();

  static const _serifFallback = ['Georgia', 'Times New Roman', 'serif'];

  static TextTheme _textTheme(TextTheme base) => base.copyWith(
    displaySmall: base.displaySmall?.copyWith(
      fontFamily: 'Georgia',
      fontFamilyFallback: _serifFallback,
      fontWeight: FontWeight.w800,
      height: 1.04,
      color: AppColors.ink,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontFamily: 'Georgia',
      fontFamilyFallback: _serifFallback,
      fontWeight: FontWeight.w800,
      fontSize: 34,
      height: 1.04,
      color: AppColors.ink,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontFamily: 'Georgia',
      fontFamilyFallback: _serifFallback,
      fontWeight: FontWeight.w800,
      fontSize: 28,
      color: AppColors.ink,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontFamily: 'Georgia',
      fontFamilyFallback: _serifFallback,
      fontWeight: FontWeight.w800,
      fontSize: 22,
      color: AppColors.ink,
    ),
    bodyLarge: base.bodyLarge?.copyWith(color: AppColors.ink),
    bodyMedium: base.bodyMedium?.copyWith(color: AppColors.muted),
  );

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green,
        primary: AppColors.green,
        surface: AppColors.paper,
        error: AppColors.red,
      ),
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Roboto', '-apple-system', 'sans-serif'],
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.greenDark,
          backgroundColor: AppColors.paper,
          side: const BorderSide(color: AppColors.soft),
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        constraints: const BoxConstraints(minHeight: 62),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.green, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.green, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.greenDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.red, width: 2),
        ),
        labelStyle: const TextStyle(
          color: AppColors.soil,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: Color(0x1C6F5239)),
        ),
      ),
      dividerColor: AppColors.soft,
    );
  }
}
