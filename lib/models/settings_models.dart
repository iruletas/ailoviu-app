import 'package:flutter/material.dart';

@immutable
class AppSettings {
  final ThemeMode themeMode;
  final Color seedColor;
  final bool amoled;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.seedColor = const Color(0xFFFF4081),
    this.amoled = false,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    Color? seedColor,
    bool? amoled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      seedColor: seedColor ?? this.seedColor,
      amoled: amoled ?? this.amoled,
    );
  }
}