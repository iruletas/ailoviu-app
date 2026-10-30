import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

/// Servicio de criptografía E2EE.
///
/// - X25519 para intercambio de claves (ECDH).
/// - HKDF-SHA256 para derivar el secreto compartido.
/// - AES-GCM para cifrar payloads.
/// - HMAC-SHA256 para firmar sobres.
/// - SHA-256 para el PIN de recuperación y la pregunta clave.
class CryptoService {
  CryptoService();

  final _x25519 = X25519();
  final _aesGcm = AesGcm.with256bits();
  final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  // ── Identidad X25519 ────────────────────────────────────────────

  Future<({String privateKeyBase64, String publicKeyBase64})>
      generateIdentityKeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    return (
      privateKeyBase64: base64Encode(privateBytes),
      publicKeyBase64: base64Encode(publicKey.bytes),
    );
  }

  Future<Uint8List> deriveSharedSecret({
    required String myPrivateKeyBase64,
    required String theirPublicKeyBase64,
  }) async {
    final privateBytes = base64Decode(myPrivateKeyBase64);
    final publicBytes = base64Decode(theirPublicKeyBase64);

    final myKeyPair = await _x25519.newKeyPairFromSeed(privateBytes);
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: SimplePublicKey(
        publicBytes,
        type: KeyPairType.x25519,
      ),
    );
    final sharedBytes = await sharedSecret.extractBytes();

    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(sharedBytes),
      nonce: utf8.encode('ailoviu-pair-v1'),
      info: utf8.encode('shared-secret'),
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  /// Deriva y devuelve en base64 el sharedSecret entre dos identidades.
  Future<String> deriveSharedSecretBase64({
    required String myPrivateKeyBase64,
    required String theirPublicKeyBase64,
  }) async {
    final bytes = await deriveSharedSecret(
      myPrivateKeyBase64: myPrivateKeyBase64,
      theirPublicKeyBase64: theirPublicKeyBase64,
    );
    return base64Encode(bytes);
  }

  // ── AES-GCM ────────────────────────────────────────────────────

  Future<({String ciphertextBase64, String nonceBase64})> encrypt({
    required Uint8List sharedSecret,
    required Map<String, dynamic> payload,
  }) async {
    final plaintext = utf8.encode(jsonEncode(payload));
    final nonce = _generateBytes(12);

    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: SecretKey(sharedSecret),
      nonce: nonce,
    );

    final combined = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    return (
      ciphertextBase64: base64Encode(combined),
      nonceBase64: base64Encode(nonce),
    );
  }

  Future<Map<String, dynamic>> decrypt({
    required Uint8List sharedSecret,
    required String ciphertextBase64,
    required String nonceBase64,
  }) async {
    final combined = base64Decode(ciphertextBase64);
    final nonce = base64Decode(nonceBase64);

    if (combined.length < 16) {
      throw CryptoException('Ciphertext demasiado corto');
    }

    final cipherText = combined.sublist(0, combined.length - 16);
    final macBytes = combined.sublist(combined.length - 16);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final plaintext = await _aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(sharedSecret),
    );

    final decoded = jsonDecode(utf8.decode(plaintext));
    if (decoded is! Map<String, dynamic>) {
      throw CryptoException('Payload no es un objeto JSON');
    }
    return decoded;
  }

  // ── AES-GCM con clave desde bytes crudos (para invites) ────────
  //
  // El invite usa una clave derivada del inviteToken (32 bytes), no
  // un sharedSecret X25519. Por eso exponemos estos dos métodos con
  // `secretKeyBytes` explícito.

  Future<({String ciphertextBase64, String nonceBase64})>
      encryptWithKeyBytes({
    required Uint8List keyBytes,
    required Map<String, dynamic> payload,
  }) async {
    final plaintext = utf8.encode(jsonEncode(payload));
    final nonce = _generateBytes(12);

    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: SecretKey(keyBytes),
      nonce: nonce,
    );

    final combined = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    return (
      ciphertextBase64: base64Encode(combined),
      nonceBase64: base64Encode(nonce),
    );
  }

  Future<Map<String, dynamic>> decryptWithKeyBytes({
    required Uint8List keyBytes,
    required String ciphertextBase64,
    required String nonceBase64,
  }) async {
    final combined = base64Decode(ciphertextBase64);
    final nonce = base64Decode(nonceBase64);

    if (combined.length < 16) {
      throw CryptoException('Ciphertext demasiado corto');
    }

    final cipherText = combined.sublist(0, combined.length - 16);
    final macBytes = combined.sublist(combined.length - 16);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final plaintext = await _aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(keyBytes),
    );

    final decoded = jsonDecode(utf8.decode(plaintext));
    if (decoded is! Map<String, dynamic>) {
      throw CryptoException('Payload no es un objeto JSON');
    }
    return decoded;
  }

  // ── Firma HMAC ─────────────────────────────────────────────────

  String signEnvelope({
    required Uint8List sharedSecret,
    required String v,
    required String id,
    required String from,
    required String to,
    required String type,
    required String createdAt,
    required String nonce,
    required String ciphertext,
  }) {
    final message = '$v|$id|$from|$to|$type|$createdAt|$nonce|$ciphertext';
    final hmac = crypto.Hmac(crypto.sha256, sharedSecret);
    return base64Encode(hmac.convert(utf8.encode(message)).bytes);
  }

  bool verifyEnvelope({
    required Uint8List sharedSecret,
    required String v,
    required String id,
    required String from,
    required String to,
    required String type,
    required String createdAt,
    required String nonce,
    required String ciphertext,
    required String signature,
  }) {
    final expected = signEnvelope(
      sharedSecret: sharedSecret,
      v: v,
      id: id,
      from: from,
      to: to,
      type: type,
      createdAt: createdAt,
      nonce: nonce,
      ciphertext: ciphertext,
    );
    return _constantTimeEquals(expected, signature);
  }

  // ── Hashes de recuperación ─────────────────────────────────────

  /// Normaliza una respuesta de pregunta clave: lowercase, sin
  /// acentos, espacios colapsados a uno. Así "  Café  " y "cafe"
  /// son equivalentes.
  String normalizeRecoveryAnswer(String raw) {
    final lower = raw.toLowerCase().trim();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final c = String.fromCharCode(rune);
      final replaced = _stripAccent(c);
      buffer.write(replaced);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _stripAccent(String c) {
    const map = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
      'ç': 'c',
    };
    return map[c] ?? c;
  }

  /// Hash de la respuesta de recuperación: SHA-256(salt || respuesta).
  String hashRecoveryAnswer({
    required String answer,
    required String saltBase64,
  }) {
    final normalized = normalizeRecoveryAnswer(answer);
    final saltBytes = base64Decode(saltBase64);
    final bytes = Uint8List.fromList([
      ...saltBytes,
      ...utf8.encode(normalized),
    ]);
    return base64Encode(crypto.sha256.convert(bytes).bytes);
  }

  /// Hash del PIN de recuperación: SHA-256(PIN || deviceId ||
  /// "ailoviu-recovery-v1"). Nunca es el PIN de desbloqueo, y se
  /// usa solo para verificar identidad en recuperación (factor B).
  String hashRecoveryPin({
    required String pin,
    required String deviceId,
  }) {
    final bytes = utf8.encode('$pin|$deviceId|ailoviu-recovery-v1');
    return base64Encode(crypto.sha256.convert(bytes).bytes);
  }

  /// Derivación del `inviteKey` a partir del `inviteToken` en
  /// base64url. SHA-256 del token crudo.
  Uint8List deriveInviteKey(String inviteTokenBase64Url) {
    final tokenBytes = base64Url.decode(inviteTokenBase64Url);
    final hash = crypto.sha256.convert(tokenBytes);
    return Uint8List.fromList(hash.bytes);
  }

  /// Proof de una solicitud de join: HMAC-SHA256(inviteKey,
  /// guestDeviceId).
  String proofForJoin({
    required Uint8List inviteKey,
    required String guestDeviceId,
  }) {
    final hmac = crypto.Hmac(crypto.sha256, inviteKey);
    return base64Encode(hmac.convert(utf8.encode(guestDeviceId)).bytes);
  }

  // ── util ────────────────────────────────────────────────────────

  Uint8List generateSalt() => _generateBytes(32);

  String generateSaltBase64() => base64Encode(generateSalt());

  Uint8List _generateBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
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

class CryptoException implements Exception {
  final String message;
  CryptoException(this.message);
  @override
  String toString() => 'CryptoException: $message';
}