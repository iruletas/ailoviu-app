import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../models/sync_models.dart';
import '../providers/sync_providers.dart';
import 'key_store.dart';
import 'linking_service.dart';

enum AuthResult {
  success,
  cancelled,
  notAvailable,
  lockedOut,
  error,
}

/// Servicio de autenticación.
///
/// Además del PIN de desbloqueo, mantiene el **PIN de recuperación**
/// (factor B de recuperación). Cuando se configura o cambia el PIN,
/// se deriva `recoveryPinHash = SHA-256(PIN || deviceId || "ailoviu-
/// recovery-v1")` y se propaga a los demás miembros del grupo.
class AuthService {
  AuthService(
    this._localAuth,
    this._keyStore,
    this._linking,
  );

  final LocalAuthentication _localAuth;
  final KeyStore _keyStore;
  final LinkingService _linking;

  // ── Sistema ──────────────────────────────────────────────────────

  Future<bool> checkSystemAuthAvailable() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

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

  // ── PIN fallback ─────────────────────────────────────────────────

  /// Configura el PIN de desbloqueo. Además, calcula el
  /// `recoveryPinHash` y lo deja en `GroupMember.recoveryPinHash`.
  ///
  /// La propagación a los demás miembros la hace el caller (la
  /// pantalla de PIN o de seguridad) con `SyncService.enqueue`.
  Future<String> setAppPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _keyStore.setPinSalt(salt);
    await _keyStore.setPinHash(hash);

    // Factor B: derivar y guardar localmente.
    final recoveryHash = await _linking.setLocalRecoveryPin(pin);
    return recoveryHash;
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

  /// Borra el PIN de desbloqueo y el `recoveryPinHash` local.
  Future<void> clearAppPin() async {
    await _keyStore.clearPin();
    await _linking.clearLocalRecoveryPin();
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

/// [AuthService] con `LinkingService` inyectado.
final authServiceProvider = FutureProvider<AuthService>((ref) async {
  return AuthService(
    LocalAuthentication(),
    ref.watch(keyStoreProvider),
    ref.watch(linkingServiceProvider),
  );
});

// ── Helpers para propagar el recoveryPinHash ─────────────────────
//
// No son providers, son funciones libres que la UI llama después de
// `setAppPin` / `clearAppPin`. Se ponen acá para que sea un solo
// import.

/// Propaga el `recoveryPinHash` a todos los miembros del grupo.
Future<void> broadcastRecoveryPin({
  required Ref ref,
  required String? recoveryPinHash,
}) async {
  final myId = await ref.read(keyStoreProvider).getDeviceId();
  if (myId == null) return;
  try {
    final sync = await ref.read(syncServiceProvider.future);
    await sync.enqueue(
      type: SyncType.recoveryPinUpdate,
      payload: {
        'deviceId': myId,
        if (recoveryPinHash != null) 'recoveryPinHash': recoveryPinHash,
      },
    );
  } catch (_) {}
}