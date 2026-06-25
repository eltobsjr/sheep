import 'package:flutter/material.dart';
import 'tokens.dart';

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
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
