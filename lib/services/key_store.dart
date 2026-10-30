import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacén seguro de claves y secretos.
///
/// Usa [FlutterSecureStorage], que en Android usa el Keystore del
/// sistema. Todo lo que se guarda aquí está cifrado en reposo y solo
/// accesible por esta app.
///
/// Claves conocidas:
/// - `device.id` — ULID del dispositivo.
/// - `device.identityPrivateKey` — X25519 privada (base64).
/// - `device.identityPublicKey` — X25519 pública (base64).
/// - `pair.peerDeviceId` — deviceId del otro dispositivo.
/// - `pair.peerIdentityPublicKey` — X25519 pública del otro (base64).
/// - `pair.sharedSecret` — secreto compartido de la pareja (base64).
/// - `pair.createdAt` — epoch ms del emparejamiento.
/// - `transport.config` — JSON de config del transporte.
/// - `pin.hash` — SHA-256 del PIN fallback (base64).
/// - `pin.salt` — salt del PIN (base64).
/// - `map.cartoApiKey` — API key de CARTO (si el usuario la configuró).
class KeyStore {
  KeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  // ── device ──────────────────────────────────────────────────────

  Future<String?> getDeviceId() => _storage.read(key: 'device.id');

  Future<void> setDeviceId(String id) =>
      _storage.write(key: 'device.id', value: id);

  Future<String?> getIdentityPrivateKey() =>
      _storage.read(key: 'device.identityPrivateKey');

  Future<void> setIdentityPrivateKey(String base64) =>
      _storage.write(key: 'device.identityPrivateKey', value: base64);

  Future<String?> getIdentityPublicKey() =>
      _storage.read(key: 'device.identityPublicKey');

  Future<void> setIdentityPublicKey(String base64) =>
      _storage.write(key: 'device.identityPublicKey', value: base64);

  // ── pair ────────────────────────────────────────────────────────

  Future<String?> getPeerDeviceId() =>
      _storage.read(key: 'pair.peerDeviceId');

  Future<void> setPeerDeviceId(String id) =>
      _storage.write(key: 'pair.peerDeviceId', value: id);

  Future<String?> getPeerIdentityPublicKey() =>
      _storage.read(key: 'pair.peerIdentityPublicKey');

  Future<void> setPeerIdentityPublicKey(String base64) =>
      _storage.write(key: 'pair.peerIdentityPublicKey', value: base64);

  Future<String?> getSharedSecret() =>
      _storage.read(key: 'pair.sharedSecret');

  Future<void> setSharedSecret(String base64) =>
      _storage.write(key: 'pair.sharedSecret', value: base64);

  Future<DateTime?> getPairCreatedAt() async {
    final raw = await _storage.read(key: 'pair.createdAt');
    if (raw == null) return null;
    final ms = int.tryParse(raw);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setPairCreatedAt(DateTime dt) => _storage.write(
        key: 'pair.createdAt',
        value: dt.millisecondsSinceEpoch.toString(),
      );

  // ── transport ───────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getTransportConfig() async {
    final raw = await _storage.read(key: 'transport.config');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setTransportConfig(Map<String, dynamic> config) =>
      _storage.write(key: 'transport.config', value: jsonEncode(config));

  Future<void> clearTransportConfig() =>
      _storage.delete(key: 'transport.config');

  // ── pin ─────────────────────────────────────────────────────────

  Future<String?> getPinHash() => _storage.read(key: 'pin.hash');

  Future<void> setPinHash(String base64) =>
      _storage.write(key: 'pin.hash', value: base64);

  Future<String?> getPinSalt() => _storage.read(key: 'pin.salt');

  Future<void> setPinSalt(String base64) =>
      _storage.write(key: 'pin.salt', value: base64);

  Future<void> clearPin() async {
    await _storage.delete(key: 'pin.hash');
    await _storage.delete(key: 'pin.salt');
  }

  // ── map ─────────────────────────────────────────────────────────

  Future<String?> getCartoKey() => _storage.read(key: 'map.cartoApiKey');

  Future<void> setCartoKey(String key) =>
      _storage.write(key: 'map.cartoApiKey', value: key);

  Future<void> clearCartoKey() => _storage.delete(key: 'map.cartoApiKey');

  // ── util ────────────────────────────────────────────────────────

  /// `true` si hay un emparejamiento activo.
  Future<bool> isPaired() async {
    final peer = await getPeerDeviceId();
    final secret = await getSharedSecret();
    return peer != null && secret != null;
  }

  /// Borra todo. Útil para "restablecer todo" o desemparejar.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Borra solo el emparejamiento, dejando device identity y PIN.
  Future<void> clearPairing() async {
    await _storage.delete(key: 'pair.peerDeviceId');
    await _storage.delete(key: 'pair.peerIdentityPublicKey');
    await _storage.delete(key: 'pair.sharedSecret');
    await _storage.delete(key: 'pair.createdAt');
    await _storage.delete(key: 'transport.config');
  }
}