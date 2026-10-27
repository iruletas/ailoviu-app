import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';
import '../services/auth_keys.dart';
import 'prefs_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// AppAuthSettings (persistido)
// ═══════════════════════════════════════════════════════════════════════

class AuthSettingsNotifier extends StateNotifier<AppAuthSettings> {
  AuthSettingsNotifier(this._prefsFuture) : super(const AppAuthSettings()) {
    _load();
  }

  final Future<SharedPreferences> _prefsFuture;

  Future<void> _load() async {
    final prefs = await _prefsFuture;

    final enabled = prefs.getBool(AuthKeys.appLockEnabled) ?? false;
    final timeoutMs = prefs.getInt(AuthKeys.appLockTimeoutMs);
    final systemAvailable =
        prefs.getBool(AuthKeys.systemAuthAvailable) ?? false;
    final pinHash = prefs.getString(AuthKeys.appPinHash);

    state = AppAuthSettings(
      loaded: true,
      appLockEnabled: enabled,
      appLockTimeout:
          timeoutMs != null ? Duration(milliseconds: timeoutMs) : null,
      systemAuthAvailable: systemAvailable,
      appPinFallbackConfigured: pinHash != null && pinHash.isNotEmpty,
    );
  }

  Future<void> setAppLockEnabled(bool value) async {
    state = state.copyWith(appLockEnabled: value);
    final prefs = await _prefsFuture;
    await prefs.setBool(AuthKeys.appLockEnabled, value);
  }

  Future<void> setAppLockTimeout(Duration? timeout) async {
    state = timeout == null
        ? state.copyWith(clearAppLockTimeout: true)
        : state.copyWith(appLockTimeout: timeout);
    final prefs = await _prefsFuture;
    if (timeout == null) {
      await prefs.remove(AuthKeys.appLockTimeoutMs);
    } else {
      await prefs.setInt(AuthKeys.appLockTimeoutMs, timeout.inMilliseconds);
    }
  }

  Future<void> setSystemAuthAvailable(bool value) async {
    if (state.systemAuthAvailable == value) return;
    state = state.copyWith(systemAuthAvailable: value);
    final prefs = await _prefsFuture;
    await prefs.setBool(AuthKeys.systemAuthAvailable, value);
  }

  /// Marca si hay PIN propio configurado. El hash lo escribe
  /// `AuthService.setAppPin`; este método solo sincroniza el flag y
  /// limpia los hashes cuando se desactiva.
  Future<void> markAppPinConfigured(bool value) async {
    state = state.copyWith(appPinFallbackConfigured: value);
    final prefs = await _prefsFuture;
    if (!value) {
      await prefs.remove(AuthKeys.appPinHash);
      await prefs.remove(AuthKeys.appPinSalt);
    }
  }
}

final authSettingsProvider =
    StateNotifierProvider<AuthSettingsNotifier, AppAuthSettings>(
  (ref) => AuthSettingsNotifier(ref.read(prefsProvider.future)),
);

// ═══════════════════════════════════════════════════════════════════════
// PrivateFeatureLock (persistido por feature)
// ═══════════════════════════════════════════════════════════════════════

class FeatureLocksNotifier
    extends StateNotifier<Map<String, PrivateFeatureLock>> {
  FeatureLocksNotifier(this._prefsFuture)
      : super({
          for (final id in PrivateFeatures.all)
            id: PrivateFeatureLock(featureId: id),
        }) {
    _load();
  }

  final Future<SharedPreferences> _prefsFuture;

  Future<void> _load() async {
    final prefs = await _prefsFuture;
    final updated = <String, PrivateFeatureLock>{};
    for (final id in PrivateFeatures.all) {
      final requires =
          prefs.getBool('${AuthKeys.featureLockPrefix}$id') ?? false;
      updated[id] = PrivateFeatureLock(
        featureId: id,
        requiresAuth: requires,
      );
    }
    state = updated;
  }

  Future<void> setRequiresAuth(String featureId, bool requires) async {
    final current = state[featureId];
    if (current == null) return;
    final updated = Map<String, PrivateFeatureLock>.from(state);
    updated[featureId] = current.copyWith(requiresAuth: requires);
    state = updated;
    final prefs = await _prefsFuture;
    await prefs.setBool(
      '${AuthKeys.featureLockPrefix}$featureId',
      requires,
    );
  }
}

final featureLocksProvider = StateNotifierProvider<FeatureLocksNotifier,
    Map<String, PrivateFeatureLock>>(
  (ref) => FeatureLocksNotifier(ref.read(prefsProvider.future)),
);

// ═══════════════════════════════════════════════════════════════════════
// AuthSession (en memoria, no persistido)
// ═══════════════════════════════════════════════════════════════════════

class AuthSessionNotifier extends StateNotifier<AuthSession> {
  AuthSessionNotifier() : super(const AuthSession());

  void unlockApp() {
    state = state.copyWith(appUnlocked: true);
  }

  void lockApp() {
    state = state.copyWith(
      appUnlocked: false,
      unlockedFeatures: const {},
    );
  }

  void unlockFeature(String featureId) {
    final updated = Set<String>.from(state.unlockedFeatures)..add(featureId);
    state = state.copyWith(unlockedFeatures: updated);
  }

  void lockFeature(String featureId) {
    final updated = Set<String>.from(state.unlockedFeatures)
      ..remove(featureId);
    state = state.copyWith(unlockedFeatures: updated);
  }
}

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSession>((ref) {
  final notifier = AuthSessionNotifier();

  ref.listen<AppAuthSettings>(authSettingsProvider, (prev, next) {
    if (prev == null || !prev.loaded) return;
    if (prev.appLockEnabled != next.appLockEnabled) {
      notifier.unlockApp();
    }
  });

  return notifier;
});