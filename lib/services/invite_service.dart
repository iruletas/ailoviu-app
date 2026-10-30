import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../models/group_models.dart';
import 'crypto_service.dart';

/// Construye y valida los QR de invitación.
///
/// Un QR de invitación contiene TODO lo necesario para que el guest
/// entre sin configurar nada:
///
/// ```
/// {
///   "version": 1,
///   "mode": "join" | "recovery",
///   "groupId": "...",
///   "hostDeviceId": "...",
///   "hostPublicKeyBase64": "...",
///   "inviteToken": "...",     // base64url, 32 bytes
///   "expiresAt": "ISO8601",
///   "encPayload": {           // transport.config cifrado con inviteKey
///     "ciphertextBase64": "...",
///     "nonceBase64": "..."
///   },
///   "recoveryQuestionPlain": "...", // opcional, si recovery
///   "recoveryOldDeviceId": "..."    // opcional, si recovery
/// }
/// ```
///
/// El `inviteKey` = SHA-256(inviteToken). El guest lo tiene porque
/// escaneó el QR. El host lo tiene porque lo generó. Nadie más.
class InviteService {
  InviteService(this._crypto);

  final CryptoService _crypto;
  final _uuid = const Uuid();

  static const int version = 1;

  /// Crea los datos del QR de join. El `transportConfig` debe estar
  /// configurado (Firebase). Lo cifra con el inviteKey.
  ///
  /// [ttl] debe ser corto (10 min). Un QR vivo para siempre es una
  /// ventana de ataque.
  Future<GroupInvitePayload> createJoinInvite({
    required String groupId,
    required String hostDeviceId,
    required String hostPublicKeyBase64,
    required Map<String, dynamic> transportConfig,
    required String recoveryQuestionPlain,
    Duration ttl = const Duration(minutes: 10),
  }) async {
    final inviteToken = _generateToken();
    final inviteKey = _crypto.deriveInviteKey(inviteToken);

    final encrypted = await _crypto.encryptWithKeyBytes(
      keyBytes: inviteKey,
      payload: transportConfig,
    );

    return GroupInvitePayload(
      version: version,
      mode: GroupInviteMode.join,
      groupId: groupId,
      hostDeviceId: hostDeviceId,
      hostPublicKeyBase64: hostPublicKeyBase64,
      inviteToken: inviteToken,
      expiresAt: DateTime.now().add(ttl),
      encPayloadCiphertextBase64: encrypted.ciphertextBase64,
      encPayloadNonceBase64: encrypted.nonceBase64,
      recoveryQuestionPlain: recoveryQuestionPlain,
      recoveryOldDeviceId: null,
    );
  }

  /// Crea los datos del QR de recuperación. **No lleva
  /// transport.config** porque el dispositivo nuevo no debe tener
  /// acceso al buzón todavía: la recuperación se valida con A+B+C
  /// por fuera, y la aprobación llega por el mismo canal de join
  /// una vez que el host la confirma.
  ///
  /// Lleva la pregunta de recuperación y el deviceId viejo (para
  /// que el host sepa a quién reemplazar).
  GroupInvitePayload createRecoveryInvite({
    required String groupId,
    required String hostDeviceId,
    required String hostPublicKeyBase64,
    required String recoveryQuestionPlain,
    required String recoveryOldDeviceId,
    Duration ttl = const Duration(minutes: 30),
  }) {
    final inviteToken = _generateToken();
    return GroupInvitePayload(
      version: version,
      mode: GroupInviteMode.recovery,
      groupId: groupId,
      hostDeviceId: hostDeviceId,
      hostPublicKeyBase64: hostPublicKeyBase64,
      inviteToken: inviteToken,
      expiresAt: DateTime.now().add(ttl),
      encPayloadCiphertextBase64: null,
      encPayloadNonceBase64: null,
      recoveryQuestionPlain: recoveryQuestionPlain,
      recoveryOldDeviceId: recoveryOldDeviceId,
    );
  }

  /// Descifra el transport config del QR de join. Lanza
  /// [InviteException] si el token es inválido, el QR expiró, o el
  /// payload no descifra.
  Future<Map<String, dynamic>> decryptTransportConfig(
    GroupInvitePayload invite,
  ) async {
    if (invite.mode != GroupInviteMode.join) {
      throw InviteException('Este QR no es de vinculación');
    }
    if (invite.isExpired) {
      throw InviteException('El QR expiró. Pide uno nuevo.');
    }
    final ct = invite.encPayloadCiphertextBase64;
    final nonce = invite.encPayloadNonceBase64;
    if (ct == null || nonce == null) {
      throw InviteException('El QR no tiene credenciales');
    }

    final inviteKey = _crypto.deriveInviteKey(invite.inviteToken);
    try {
      return await _crypto.decryptWithKeyBytes(
        keyBytes: inviteKey,
        ciphertextBase64: ct,
        nonceBase64: nonce,
      );
    } catch (_) {
      throw InviteException('No se pudo descifrar el QR');
    }
  }

  /// Calcula el proof para una solicitud de join.
  String proofFor({
    required GroupInvitePayload invite,
    required String guestDeviceId,
  }) {
    final inviteKey = _crypto.deriveInviteKey(invite.inviteToken);
    return _crypto.proofForJoin(
      inviteKey: inviteKey,
      guestDeviceId: guestDeviceId,
    );
  }

  /// Verifica el proof de una solicitud de join contra un invite
  /// conocido.
  bool verifyProof({
    required String inviteToken,
    required String guestDeviceId,
    required String proof,
  }) {
    try {
      final inviteKey = _crypto.deriveInviteKey(inviteToken);
      final expected = _crypto.proofForJoin(
        inviteKey: inviteKey,
        guestDeviceId: guestDeviceId,
      );
      return _constantTimeEquals(expected, proof);
    } catch (_) {
      return false;
    }
  }

  String _generateToken() {
    final bytes = _crypto.generateSalt();
    // base64url sin padding, 32 bytes -> 43 chars.
    return base64Url.encode(bytes).replaceAll('=', '');
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

enum GroupInviteMode { join, recovery }

/// Datos completos del QR, tal como viajan al guest.
///
/// Es `@immutable` porque el guest lo recibe y no lo modifica.
class GroupInvitePayload {
  final int version;
  final GroupInviteMode mode;
  final String groupId;
  final String hostDeviceId;
  final String hostPublicKeyBase64;
  final String inviteToken;
  final DateTime expiresAt;
  final String? encPayloadCiphertextBase64;
  final String? encPayloadNonceBase64;
  final String? recoveryQuestionPlain;
  final String? recoveryOldDeviceId;

  const GroupInvitePayload({
    required this.version,
    required this.mode,
    required this.groupId,
    required this.hostDeviceId,
    required this.hostPublicKeyBase64,
    required this.inviteToken,
    required this.expiresAt,
    this.encPayloadCiphertextBase64,
    this.encPayloadNonceBase64,
    this.recoveryQuestionPlain,
    this.recoveryOldDeviceId,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isJoin => mode == GroupInviteMode.join;
  bool get isRecovery => mode == GroupInviteMode.recovery;

  Map<String, dynamic> toJson() => {
        'version': version,
        'mode': mode.name,
        'groupId': groupId,
        'hostDeviceId': hostDeviceId,
        'hostPublicKeyBase64': hostPublicKeyBase64,
        'inviteToken': inviteToken,
        'expiresAt': expiresAt.toIso8601String(),
        if (encPayloadCiphertextBase64 != null)
          'encPayloadCiphertextBase64': encPayloadCiphertextBase64,
        if (encPayloadNonceBase64 != null)
          'encPayloadNonceBase64': encPayloadNonceBase64,
        if (recoveryQuestionPlain != null)
          'recoveryQuestionPlain': recoveryQuestionPlain,
        if (recoveryOldDeviceId != null)
          'recoveryOldDeviceId': recoveryOldDeviceId,
      };

  static GroupInvitePayload fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    if (version != InviteService.version) {
      throw InviteException(
        'Versión de QR no soportada ($version). Actualiza la app.',
      );
    }
    final modeName = json['mode'] as String? ?? 'join';
    final mode = GroupInviteMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => GroupInviteMode.join,
    );
    return GroupInvitePayload(
      version: version,
      mode: mode,
      groupId: json['groupId'] as String,
      hostDeviceId: json['hostDeviceId'] as String,
      hostPublicKeyBase64: json['hostPublicKeyBase64'] as String,
      inviteToken: json['inviteToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      encPayloadCiphertextBase64:
          json['encPayloadCiphertextBase64'] as String?,
      encPayloadNonceBase64: json['encPayloadNonceBase64'] as String?,
      recoveryQuestionPlain: json['recoveryQuestionPlain'] as String?,
      recoveryOldDeviceId: json['recoveryOldDeviceId'] as String?,
    );
  }

  /// Para el QR: JSON compacto en un solo string.
  String encodeForQr() => jsonEncode(toJson());

  /// Para el escáner: parsea el string del QR.
  static GroupInvitePayload fromQrString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw InviteException('QR malformado');
      }
      return GroupInvitePayload.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on InviteException {
      rethrow;
    } catch (_) {
      throw InviteException('QR malformado');
    }
  }
}

class InviteException implements Exception {
  final String message;
  InviteException(this.message);
  @override
  String toString() => message;
}