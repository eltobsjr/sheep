import 'package:flutter/material.dart';
import 'sheep_colors.dart';
import 'tokens.dart';

// ─────────────────────────────── dark tokens ─────────────────────────────────
const Color _darkBg = Color(0xFF0A0A0A);       // ink
const Color _darkSurface = Color(0xFF1C1C1C);  // charcoal
const Color _darkCard = Color(0xFF242424);
const Color _darkNav = Color(0xFF141414);
const Color _darkFg = Color(0xFFFAFAFA);       // paper
const Color _darkMuted = Color(0xFF6B6B6B);    // slate
const Color _darkWool = Color(0xFF2A2A2A);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  extensions: const [SheepColors.dark],
  scaffoldBackgroundColor: _darkBg,
  shadowColor: Colors.transparent,
  splashColor: Colors.transparent,
  highlightColor: Colors.transparent,
  colorScheme: const ColorScheme.dark(
    surface: _darkSurface,
    onSurface: _darkFg,
    primary: _darkFg,
    onPrimary: _darkBg,
    secondary: _darkWool,
    onSecondary: _darkFg,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: _darkBg,
    foregroundColor: _darkFg,
    elevation: 0,
    scrolledUnderElevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: _darkNav,
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    indicatorColor: Colors.transparent,
    indicatorShape: const RoundedRectangleBorder(),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w700,
        fontSize: 9,
        color: selected ? _darkFg : _darkMuted,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(color: selected ? _darkFg : _darkMuted, size: 22);
    }),
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    height: 56,
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700, color: _darkFg),
    displayMedium: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700, color: _darkFg),
    displaySmall: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700, color: _darkFg),
    headlineLarge: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700, color: _darkFg),
    headlineMedium: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700, color: _darkFg),
    headlineSmall: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700, color: _darkFg),
    bodyLarge: TextStyle(color: _darkFg),
    bodyMedium: TextStyle(color: _darkFg),
    bodySmall: TextStyle(color: _darkMuted),
  ),
  cardTheme: const CardThemeData(
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    color: _darkCard,
  ),
);

// ─────────────────────────────── light theme ─────────────────────────────────

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  extensions: const [SheepColors.light],
  scaffoldBackgroundColor: paper,
  shadowColor: Colors.transparent,
  splashColor: Colors.transparent,
  highlightColor: Colors.transparent,
  colorScheme: const ColorScheme.light(
    surface: paper,
    onSurface: ink,
    primary: ink,
    onPrimary: paper,
    secondary: wool,
    onSecondary: ink,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    indicatorColor: Colors.transparent,
    indicatorShape: const RoundedRectangleBorder(),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w700,
        fontSize: 9,
        color: selected ? ink : slate,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(color: selected ? ink : slate, size: 22);
    }),
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    height: 56,
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700),
    displayMedium: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700),
    displaySmall: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700),
    headlineLarge: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700),
    headlineSmall: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700),
  ),
  cardTheme: const CardThemeData(
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    color: wool,
  ),
);
