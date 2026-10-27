import 'package:flutter/foundation.dart';

/// Configuración global de autenticación de la app.
///
/// El método principal de desbloqueo es el del sistema operativo
/// (`local_auth`): huella, rostro, PIN o patrón del dispositivo,
/// los que el usuario tenga configurados. Solo si el dispositivo
/// no tiene bloqueo de pantalla se ofrece un PIN propio de la app
/// como fallback.
@immutable
class AppAuthSettings {
  /// `false` hasta que `SharedPreferences` termine de cargar. El gate
  /// de auth usa este flag para no decidir antes de tiempo.
  final bool loaded;

  /// Si `true`, la app pide autenticación al abrir y respeta
  /// [appLockTimeout] al volver del background.
  final bool appLockEnabled;

  /// Tiempo en background antes de re-bloquear.
  ///
  /// `null` = sin temporizador. Una vez desbloqueada, la app se queda
  /// desbloqueada hasta que el usuario bloquee manualmente o la
  /// cierre.
  final Duration? appLockTimeout;

  /// Indica si el dispositivo puede autenticar con `local_auth`.
  /// Se resuelve una vez al arrancar y se persiste para no volver a
  /// consultarlo en cada build.
  final bool systemAuthAvailable;

  /// Si `true`, hay un PIN propio de la app configurado como fallback
  /// para dispositivos sin bloqueo de pantalla.
  final bool appPinFallbackConfigured;

  const AppAuthSettings({
    this.loaded = false,
    this.appLockEnabled = false,
    this.appLockTimeout,
    this.systemAuthAvailable = false,
    this.appPinFallbackConfigured = false,
  });

  AppAuthSettings copyWith({
    bool? loaded,
    bool? appLockEnabled,
    Duration? appLockTimeout,
    bool clearAppLockTimeout = false,
    bool? systemAuthAvailable,
    bool? appPinFallbackConfigured,
  }) {
    return AppAuthSettings(
      loaded: loaded ?? this.loaded,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockTimeout: clearAppLockTimeout
          ? null
          : (appLockTimeout ?? this.appLockTimeout),
      systemAuthAvailable: systemAuthAvailable ?? this.systemAuthAvailable,
      appPinFallbackConfigured:
          appPinFallbackConfigured ?? this.appPinFallbackConfigured,
    );
  }

  /// `true` si hay al menos un método de desbloqueo disponible.
  bool get hasAnyUnlockMethod =>
      systemAuthAvailable || appPinFallbackConfigured;
}

/// Configuración de bloqueo de una función privada.
///
/// Cada feature privada (diario, cartas, estados privados, etc.)
/// decide si exige auth al entrar. Sin temporizador: al salir de la
/// función, se vuelve a pedir auth la próxima vez.
@immutable
class PrivateFeatureLock {
  final String featureId;
  final bool requiresAuth;

  const PrivateFeatureLock({
    required this.featureId,
    this.requiresAuth = false,
  });

  PrivateFeatureLock copyWith({bool? requiresAuth}) {
    return PrivateFeatureLock(
      featureId: featureId,
      requiresAuth: requiresAuth ?? this.requiresAuth,
    );
  }
}

/// Estado de la sesión de auth en foreground.
///
/// Vive solo en memoria: no se persiste. Al cerrar la app, se pierde.
@immutable
class AuthSession {
  /// `true` cuando la app ya se desbloqueó en esta sesión de
  /// foreground. Empieza en `false`; el gate decide si eso importa
  /// según `AppAuthSettings.appLockEnabled`.
  final bool appUnlocked;

  /// Features privadas desbloqueadas en esta sesión.
  /// Al salir de una feature, se remueve su id, de modo que la
  /// próxima entrada vuelve a pedir auth.
  final Set<String> unlockedFeatures;

  const AuthSession({
    this.appUnlocked = false,
    this.unlockedFeatures = const {},
  });

  AuthSession copyWith({
    bool? appUnlocked,
    Set<String>? unlockedFeatures,
  }) {
    return AuthSession(
      appUnlocked: appUnlocked ?? this.appUnlocked,
      unlockedFeatures: unlockedFeatures ?? this.unlockedFeatures,
    );
  }

  bool isFeatureUnlocked(String featureId) =>
      unlockedFeatures.contains(featureId);
}