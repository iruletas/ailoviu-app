import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/group_models.dart';

/// Almacén seguro de claves y secretos.
///
/// Usa [FlutterSecureStorage], que en Android usa el Keystore del
/// sistema. Todo lo que se guarda aquí está cifrado en reposo y solo
/// accesible por esta app.
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

  Future<void> setIdentityPrivateKey(String b64) =>
      _storage.write(key: 'device.identityPrivateKey', value: b64);

  Future<String?> getIdentityPublicKey() =>
      _storage.read(key: 'device.identityPublicKey');

  Future<void> setIdentityPublicKey(String b64) =>
      _storage.write(key: 'device.identityPublicKey', value: b64);

  // ── group ───────────────────────────────────────────────────────

  Future<String?> getGroupId() => _storage.read(key: 'group.id');

  Future<void> setGroupId(String id) =>
      _storage.write(key: 'group.id', value: id);

  Future<String?> getHostDeviceId() =>
      _storage.read(key: 'group.hostDeviceId');

  Future<void> setHostDeviceId(String id) =>
      _storage.write(key: 'group.hostDeviceId', value: id);

  Future<Map<String, GroupMember>> getGroupMembers() async {
    final raw = await _storage.read(key: 'group.members');
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(
          k,
          GroupMember.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> setGroupMembers(Map<String, GroupMember> members) {
    final json = members.map((k, v) => MapEntry(k, v.toJson()));
    return _storage.write(key: 'group.members', value: jsonEncode(json));
  }

  // ── secrets (uno por peer) ─────────────────────────────────────

  Future<Map<String, String>> _getSecretsRaw() async {
    final raw = await _storage.read(key: 'group.secrets');
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _setSecretsRaw(Map<String, String> secrets) =>
      _storage.write(key: 'group.secrets', value: jsonEncode(secrets));

  Future<String?> getPeerSharedSecret(String peerDeviceId) async {
    final secrets = await _getSecretsRaw();
    return secrets[peerDeviceId];
  }

  Future<void> setPeerSharedSecret(
    String peerDeviceId,
    String secretBase64,
  ) async {
    final secrets = await _getSecretsRaw();
    secrets[peerDeviceId] = secretBase64;
    await _setSecretsRaw(secrets);
  }

  Future<void> removePeer(String peerDeviceId) async {
    final secrets = await _getSecretsRaw();
    secrets.remove(peerDeviceId);
    await _setSecretsRaw(secrets);

    final members = await getGroupMembers();
    members.remove(peerDeviceId);
    await setGroupMembers(members);
  }

  Future<void> clearGroup() async {
    await _storage.delete(key: 'group.id');
    await _storage.delete(key: 'group.hostDeviceId');
    await _storage.delete(key: 'group.members');
    await _storage.delete(key: 'group.secrets');
    await _storage.delete(key: 'transport.config');
    await _storage.delete(key: 'group.recoveryQuestionPlain');
    await _storage.delete(key: 'group.recoveryQuestionHash');
    await _storage.delete(key: 'group.recoveryQuestionSalt');
    await _storage.delete(key: 'group.peerRecoveryPins');
  }

  // ── recovery question ──────────────────────────────────────────

  Future<RecoveryQuestion?> getRecoveryQuestion() async {
    final plain = await _storage.read(key: 'group.recoveryQuestionPlain');
    final hash = await _storage.read(key: 'group.recoveryQuestionHash');
    final salt = await _storage.read(key: 'group.recoveryQuestionSalt');
    if (plain == null || hash == null || salt == null) return null;
    return RecoveryQuestion(
      questionPlain: plain,
      answerHash: hash,
      answerSalt: salt,
    );
  }

  Future<void> setRecoveryQuestion(RecoveryQuestion q) async {
    await _storage.write(
      key: 'group.recoveryQuestionPlain',
      value: q.questionPlain,
    );
    await _storage.write(
      key: 'group.recoveryQuestionHash',
      value: q.answerHash,
    );
    await _storage.write(
      key: 'group.recoveryQuestionSalt',
      value: q.answerSalt,
    );
  }

  Future<void> clearRecoveryQuestion() async {
    await _storage.delete(key: 'group.recoveryQuestionPlain');
    await _storage.delete(key: 'group.recoveryQuestionHash');
    await _storage.delete(key: 'group.recoveryQuestionSalt');
  }

  // ── peer recovery PINs ─────────────────────────────────────────
  //
  // Cada miembro guarda el `recoveryHash` de los demás para poder
  // verificar su identidad en una recuperación (factor B).
  // Se sincroniza cuando alguien cambia su PIN.

  Future<Map<String, String>> getPeerRecoveryPins() async {
    final raw = await _storage.read(key: 'group.peerRecoveryPins');
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> setPeerRecoveryPin(
    String peerDeviceId,
    String recoveryHash,
  ) async {
    final pins = await getPeerRecoveryPins();
    pins[peerDeviceId] = recoveryHash;
    await _storage.write(
      key: 'group.peerRecoveryPins',
      value: jsonEncode(pins),
    );
  }

  Future<void> removePeerRecoveryPin(String peerDeviceId) async {
    final pins = await getPeerRecoveryPins();
    pins.remove(peerDeviceId);
    await _storage.write(
      key: 'group.peerRecoveryPins',
      value: jsonEncode(pins),
    );
  }

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
  Future<void> setPinHash(String b64) =>
      _storage.write(key: 'pin.hash', value: b64);
  Future<String?> getPinSalt() => _storage.read(key: 'pin.salt');
  Future<void> setPinSalt(String b64) =>
      _storage.write(key: 'pin.salt', value: b64);

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

  /// `true` si hay un grupo con al menos otro miembro aprobado.
  Future<bool> isLinked() async {
    final groupId = await getGroupId();
    if (groupId == null) return false;
    final members = await getGroupMembers();
    final myId = await getDeviceId();
    if (myId == null) return false;
    return members.values.any(
      (m) => m.deviceId != myId && m.approved,
    );
  }

  Future<void> clearAll() => _storage.deleteAll();
}