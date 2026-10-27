import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Claves (prefijo settings.) ────────────────────────────────────────────
const _kThemeMode = 'settings.themeMode';
const _kSeedColor = 'settings.seedColor';
const _kAmoled = 'settings.amoled';

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

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final modeStr = prefs.getString(_kThemeMode);
    final seedInt = prefs.getInt(_kSeedColor);
    final amoled = prefs.getBool(_kAmoled) ?? false;

    state = AppSettings(
      themeMode: _parseThemeMode(modeStr),
      seedColor: seedInt != null ? Color(seedInt) : const Color(0xFFFF4081),
      amoled: amoled,
    );
  }

  static ThemeMode _parseThemeMode(String? s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _serializeThemeMode(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, _serializeThemeMode(mode));
  }

  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColor: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSeedColor, color.toARGB32());
  }

  Future<void> setAmoled(bool value) async {
    state = state.copyWith(amoled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAmoled, value);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);