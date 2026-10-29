import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../providers/sync_providers.dart';
import 'key_store.dart';

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
///   cuando el dispositivo no tiene bloqueo de pantalla. El hash y el
///   salt viven en [KeyStore] (Android Keystore), no en
///   SharedPreferences.
class AuthService {
  AuthService(this._localAuth, this._keyStore);

  final LocalAuthentication _localAuth;
  final KeyStore _keyStore;

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
    await _keyStore.setPinSalt(salt);
    await _keyStore.setPinHash(hash);
  }

  Future<bool> verifyAppPin(String pin) async {
    try {
      final salt = await _keyStore.getPinSalt();
      final storedHash = await _keyStore.getPinHash();
      if (salt == null || storedHash == null) return false;
      final inputHash = _hashPin(pin, salt);
      return _constantTimeEquals(storedHash, inputHash);
    } catch (_) {
      return false;
    }
  }

  Future<void> clearAppPin() => _keyStore.clearPin();

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

/// [AuthService] listo para usar.
///
/// Sigue siendo `FutureProvider` para no tocar a los consumidores
/// (`ref.read(authServiceProvider.future)`).
final authServiceProvider = FutureProvider<AuthService>((ref) async {
  final keyStore = ref.watch(keyStoreProvider);
  return AuthService(LocalAuthentication(), keyStore);
});
