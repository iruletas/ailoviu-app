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
///
/// El "secreto compartido" de la pareja es un secreto de 32 bytes
/// derivado de X25519 entre las dos identidades. Se usa como clave de
/// sesión para AES-GCM y HMAC. Es estático (no hay ratchet), pero es
/// seguro mientras el secreto no se filtre. Migrar a Double Ratchet
/// es un cambio aislado en este archivo.
class CryptoService {
  CryptoService();

  final _x25519 = X25519();
  final _aesGcm = AesGcm.with256bits();
  final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  // ── Identidad X25519 ────────────────────────────────────────────

  /// Genera un par de claves X25519 nuevo. Devuelve las claves en
  /// base64 (privada y pública).
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

  /// Deriva un secreto compartido de 32 bytes entre dos identidades
  /// X25519. El resultado es el mismo desde ambos lados.
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

    // HKDF para derivar 32 bytes limpios.
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(sharedBytes),
      nonce: utf8.encode('ailoviu-pair-v1'),
      info: utf8.encode('shared-secret'),
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  // ── AES-GCM ────────────────────────────────────────────────────

  /// Cifra un payload con AES-GCM. Devuelve `ciphertext` (base64) y
  /// `nonce` (base64, 12 bytes).
  Future<({String ciphertextBase64, String nonceBase64})> encrypt({
    required Uint8List sharedSecret,
    required Map<String, dynamic> payload,
  }) async {
    final plaintext = utf8.encode(jsonEncode(payload));
    final nonce = _generateNonce(12);

    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: SecretKey(sharedSecret),
      nonce: nonce,
    );

    // SecretBox tiene cipherText + MAC. Concatenamos ambos para que el
    // receptor pueda verificar con el mismo paquete.
    final combined = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    return (
      ciphertextBase64: base64Encode(combined),
      nonceBase64: base64Encode(nonce),
    );
  }

  /// Descifra un payload AES-GCM. Lanza [CryptoException] si la
  /// autenticación falla.
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

  // ── Firma HMAC ─────────────────────────────────────────────────

  /// Firma los campos del sobre que no deben alterarse.
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

  /// Verifica la firma del sobre. `true` si es válida.
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

  // ── util ────────────────────────────────────────────────────────

  Uint8List _generateNonce(int length) {
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