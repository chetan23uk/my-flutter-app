// lib/theme.dart
import 'package:flutter/material.dart';

/// App me available themes (skins)
enum AppTheme {
  darkPink,   // default – current theme
  amoledPink,
  deepPurple,
  warmOrange,
  cyanMusic,
}

/// global notifier – theme change karne ke liye
final ValueNotifier<AppTheme> currentTheme =
ValueNotifier<AppTheme>(AppTheme.darkPink);

/// purana function bhi support me rakha hai
ThemeData buildDarkTheme() => buildTheme(AppTheme.darkPink);

ThemeData buildTheme(AppTheme theme) {
  const baseTextColor = Colors.white;
  const baseSubtitle = Colors.white70;

  switch (theme) {
  // ---------------- 1. NEON DARK PINK ----------------
    case AppTheme.darkPink:
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: Colors.pinkAccent, // ✅ same as before
        colorScheme: const ColorScheme.dark(
          primary: Colors.pinkAccent,     // ✅ same
          secondary: Colors.pink,         // ✅ same
          tertiary: Color(0xFF7E57FF),    // ✅ ONLY folder tile purple
          onTertiary: Colors.white,       // ✅ folder icon white
          surface: Color(0xFF181818),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          iconTheme: IconThemeData(color: baseTextColor),
          titleTextStyle: TextStyle(
            color: baseTextColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: baseTextColor, fontSize: 16),
          bodyMedium: TextStyle(color: baseSubtitle, fontSize: 14),
          titleLarge: TextStyle(color: baseTextColor, fontSize: 22),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF1F1F1F),
          selectedColor:
          Colors.pinkAccent.withValues(alpha: 0.15), // was withOpacity
          labelStyle: const TextStyle(color: baseTextColor),
          secondaryLabelStyle: const TextStyle(color: baseTextColor),
          shape: StadiumBorder(
            side: BorderSide(
              color: Colors.pinkAccent.withValues(alpha: 0.6),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF181818),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF202020),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.pinkAccent,
          foregroundColor: Colors.white,
          shape: CircleBorder(),
        ),
      );

  // ---------------- 2. AMOLED BLACK + PINK ----------------
    case AppTheme.amoledPink:
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFFF4DA6),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF4DA6),
          secondary: Color(0xFFFF4DA6),
          surface: Color(0xFF101010),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: IconThemeData(color: baseTextColor),
          titleTextStyle: TextStyle(
            color: baseTextColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF151515),
          selectedColor:
          Color(0xFFFF4DA6).withValues(alpha: 0.18),
          labelStyle: const TextStyle(color: baseTextColor),
          secondaryLabelStyle: const TextStyle(color: baseTextColor),
          shape: StadiumBorder(
            side: BorderSide(
              color: const Color(0xFFFF4DA6).withValues(alpha: 0.7),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF101010),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF151515),
        ),
      );

  // ---------------- 3. DEEP PURPLE ----------------
    case AppTheme.deepPurple:
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0A16),
        primaryColor: const Color(0xFFBB86FC),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFBB86FC),
          secondary: Color(0xFF7C4DFF),
          surface: Color(0xFF1A1025),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0A16),
          elevation: 0,
          iconTheme: IconThemeData(color: baseTextColor),
          titleTextStyle: TextStyle(
            color: baseTextColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF1A1025),
          selectedColor:
          Color(0xFFBB86FC).withValues(alpha: 0.2),
          labelStyle: const TextStyle(color: baseTextColor),
          secondaryLabelStyle: const TextStyle(color: baseTextColor),
          shape: StadiumBorder(
            side: BorderSide(
              color: Color(0xFFBB86FC).withValues(alpha: 0.7),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1025),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF241130),
        ),
      );

  // ---------------- 4. WARM ORANGE ----------------
    case AppTheme.warmOrange:
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121013),
        primaryColor: const Color(0xFFFFB74D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB74D),
          secondary: Color(0xFFFF9800),
          surface: Color(0xFF221711),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121013),
          elevation: 0,
          iconTheme: IconThemeData(color: baseTextColor),
          titleTextStyle: TextStyle(
            color: baseTextColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF221711),
          selectedColor:
          Color(0xFFFFB74D).withValues(alpha: 0.22),
          labelStyle: const TextStyle(color: baseTextColor),
          secondaryLabelStyle: const TextStyle(color: baseTextColor),
          shape: StadiumBorder(
            side: BorderSide(
              color: Color(0xFFFFB74D).withValues(alpha: 0.7),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF221711),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF2A1A12),
        ),
      );
       //-----------cyantheme ---------------
    case AppTheme.cyanMusic:
        return ThemeData(
          brightness: Brightness.dark,

          scaffoldBackgroundColor: const Color(0xFF070E1A), // dark blue bg

          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2FE6E6),   // main cyan (folders, buttons)
            secondary: Color(0xFF5CF3F3), // light cyan
            surface: Color(0xFF0C1A2A),
          ),

          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: IconThemeData(color: Color(0xFF2FE6E6)),
          ),

          textTheme: const TextTheme(
            titleLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Color(0xFFB0C7D8)),
            bodySmall: TextStyle(color: Color(0xFF8FA3B8)),
          ),

          iconTheme: const IconThemeData(
            color: Color(0xFF2FE6E6),
          ),
        );
  }
}
