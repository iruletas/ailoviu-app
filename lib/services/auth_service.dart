import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/prefs_provider.dart';
import 'auth_keys.dart';

/// Resultado de un intento de autenticación con el sistema.
enum AuthResult {
  success,
  cancelled,
  notAvailable,
  lockedOut,
  error,
}

/// Servicio de autenticación.
///
/// - [authenticateWithSystem]: delega al sistema operativo
///   (`BiometricPrompt` en Android). El sistema muestra huella/PIN/
///   patrón/contraseña, lo que el usuario tenga configurado.
/// - [verifyAppPin] / [setAppPin]: PIN propio de la app como fallback
///   cuando el dispositivo no tiene bloqueo de pantalla.
class AuthService {
  AuthService(this._localAuth, this._prefs);

  final LocalAuthentication _localAuth;
  final SharedPreferences _prefs;

  // ── Sistema ────────────────────────────────────────────────────────

  /// `true` si el dispositivo puede autenticar con el sistema.
  Future<bool> checkSystemAuthAvailable() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Abre el prompt del sistema. En Android esto muestra el
  /// `BiometricPrompt` con todos los métodos que el usuario tenga
  /// configurados.
  Future<AuthResult> authenticateWithSystem() async {
    try {
      final success = await _localAuth.authenticate(
        localizedReason: 'Desbloquea Ailoviu para continuar',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return success ? AuthResult.success : AuthResult.cancelled;
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NotAvailable':
        case 'NotEnrolled':
        case 'no_fragment_activity':
        case 'PasscodeNotSet':
          return AuthResult.notAvailable;
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return AuthResult.lockedOut;
        default:
          return AuthResult.error;
      }
    } catch (_) {
      return AuthResult.error;
    }
  }

  // ── PIN fallback ───────────────────────────────────────────────────

  Future<void> setAppPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _prefs.setString(AuthKeys.appPinSalt, salt);
    await _prefs.setString(AuthKeys.appPinHash, hash);
  }

  Future<bool> verifyAppPin(String pin) async {
    final salt = _prefs.getString(AuthKeys.appPinSalt);
    final storedHash = _prefs.getString(AuthKeys.appPinHash);
    if (salt == null || storedHash == null) return false;
    final inputHash = _hashPin(pin, salt);
    return _constantTimeEquals(storedHash, inputHash);
  }

  Future<void> clearAppPin() async {
    await _prefs.remove(AuthKeys.appPinSalt);
    await _prefs.remove(AuthKeys.appPinHash);
  }

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// [AuthService] listo para usar, una vez que `SharedPreferences`
/// terminó de cargar.
final authServiceProvider = FutureProvider<AuthService>((ref) async {
  final prefs = await ref.watch(prefsProvider.future);
  return AuthService(LocalAuthentication(), prefs);
});