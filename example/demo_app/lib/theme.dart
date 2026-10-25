import 'package:flutter/material.dart';

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00695C),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
  );
}
