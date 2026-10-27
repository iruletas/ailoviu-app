import 'package:flutter/material.dart';

ThemeData buildTheme({
  required Brightness brightness,
  required Color seed,
  bool amoled = false,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );

  if (!amoled || brightness != Brightness.dark) {
    return ThemeData(colorScheme: scheme, useMaterial3: true);
  }

  // AMOLED: negros puros en superficies grandes, manteniendo el resto de M3.
  final amoledScheme = scheme.copyWith(
    surface: Colors.black,
    surfaceContainerLowest: Colors.black,
    surfaceContainerLow: const Color(0xFF0A0A0A),
    surfaceContainer: const Color(0xFF121212),
    surfaceContainerHigh: const Color(0xFF1A1A1A),
    surfaceContainerHighest: const Color(0xFF222222),
  );

  return ThemeData(
    colorScheme: amoledScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.black,
    canvasColor: Colors.black,
  );
}