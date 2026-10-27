import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_models.dart';
import 'prefs_provider.dart';

export '../models/settings_models.dart';

// ── Claves (prefijo settings.) ────────────────────────────────────────────
const _kThemeMode = 'settings.themeMode';
const _kSeedColor = 'settings.seedColor';
const _kAmoled = 'settings.amoled';

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._prefsFuture) : super(const AppSettings()) {
    _load();
  }

  final Future<SharedPreferences> _prefsFuture;

  Future<void> _load() async {
    final prefs = await _prefsFuture;

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
    final prefs = await _prefsFuture;
    await prefs.setString(_kThemeMode, _serializeThemeMode(mode));
  }

  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColor: color);
    final prefs = await _prefsFuture;
    await prefs.setInt(_kSeedColor, color.toARGB32());
  }

  Future<void> setAmoled(bool value) async {
    state = state.copyWith(amoled: value);
    final prefs = await _prefsFuture;
    await prefs.setBool(_kAmoled, value);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(ref.read(prefsProvider.future)),
);