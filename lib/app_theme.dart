// lib/app_theme.dart
// BadminCAB – Jay Score dark theme palette
//
// Colours lifted directly from Jay Score dark theme CSS variables:
//   --bg        #0c111c   body background (deep blue-black)
//   --panel     #0f172a   card / AppBar base
//   --panel-2   #131a2f   card gradient end / inputs
//   --text      #e6e8ec   primary text
//   --muted     #9aa2ad   secondary / hint text
//   --accent    #5aaef8   sky blue  → Select Players, nav selected
//   --accent-2  #37c49b   teal green → Assign, Save, all "go" actions
//   --danger    #f87171   soft red  → Delete / destructive only
//   --border    #1f2a3a   subtle dark border
//
// Chip colours: field-tested, UNCHANGED
//   Playing  #FFE082 bg / #FFB300 border
//   Resting  #80CBC4 bg / #00897B border

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Core colours – from Jay Score dark theme ──────────────────────────────
  static const Color bg      = Color(0xFF0C111C); // body canvas
  static const Color panel   = Color(0xFF0F172A); // card base / AppBar
  static const Color panel2  = Color(0xFF131A2F); // card gradient end
  static const Color border  = Color(0xFF1F2A3A); // card borders

  static const Color textPrimary = Color(0xFFE6E8EC);
  static const Color textMuted   = Color(0xFF9AA2AD);

  static const Color accent  = Color(0xFF5AAEF8); // sky blue
  static const Color accent2 = Color(0xFF37C49B); // teal green
  static const Color danger  = Color(0xFFF87171); // soft red

  static const Color breakColor = Color(0xFFF97316); // orange – break timer only
  
  static const Color rep1  = Color(0xFFF87171); // 
  static const Color rep2  = Color(0xFF5AAEF8); // 
  static const Color rep4  = Color(0xFFFFDB58); // 
  static const Color rep3  = Color(0xFF37C49B); // 

  // ── Semantic aliases ───────────────────────────────────────────────────────
  // Old light-theme token names mapped to dark equivalents so every other
  // screen compiles without changes.
  static const Color primary       = panel;      // AppBar bg / timer card
  static const Color primaryLight  = accent;     // edit icons, lighter buttons
  static const Color select        = accent;     // Select Players button
  static const Color action        = accent2;    // Assign / Save / Confirm
  static const Color surface       = bg;         // scaffold canvas
  static const Color navSelected   = accent;     // bottom nav active
  static const Color navUnselected = textMuted;  // bottom nav inactive

  // ── Glow gradient – blue → teal (Jay Score card.accent treatment) ─────────
  // Used by _GlowCard in dashboard_screen.dart.
  // Must be LinearGradient (not abstract Gradient) to be const.
  static const LinearGradient glowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accent2],
  );

  // ── Chip colours – field-tested, UNCHANGED ────────────────────────────────
  static const Color chipPlayBg     = Color(0xFFFFE082);
  static const Color chipPlayBorder = Color(0xFFFFB300);
  static const Color chipPlayText   = Color(0xFF1A1A1A);

  static const Color chipRestBg     = Color(0xFF80CBC4);
  static const Color chipRestBorder = Color(0xFF00897B);
  static const Color chipRestText   = Color(0xFF1A1A1A);

  // Resting players card – very dark teal panel
  static const Color restCardBg     = Color(0xFF0D1F1E);
  static const Color restCardBorder = Color(0xFF1A3330);

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: accent,
          secondary: accent2,
          surface: panel,
          error: danger,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: textPrimary,
        ),
        scaffoldBackgroundColor: bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: panel,
          foregroundColor: textPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        // CardThemeData (not CardTheme) – required since Flutter 3.17+
        cardTheme: CardThemeData(
          color: panel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: border),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
          labelStyle: const TextStyle(color: textMuted),
          hintStyle: const TextStyle(color: textMuted),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: panel,
          selectedItemColor: accent,
          unselectedItemColor: textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(color: border),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: panel2,
          contentTextStyle: const TextStyle(color: textPrimary),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: border),
          ),
        ),
        chipTheme: ChipThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // DialogThemeData (not DialogTheme) – required since Flutter 3.19+
        dialogTheme: DialogThemeData(
          backgroundColor: panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: border),
          ),
        ),
      );
}