import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../models/group_models.dart';
import 'crypto_service.dart';

class InviteService {
  InviteService(this._crypto);

  final CryptoService _crypto;
  final _uuid = const Uuid();

  static const int version = 1;

  Future<GroupInvitePayload> createJoinInvite({
    required String groupId,
    required String hostDeviceId,
    required String hostPublicKeyBase64,
    required Map<String, dynamic> transportConfig,
    required String recoveryQuestionPlain,
    String? cartoKey,
    Duration ttl = const Duration(minutes: 10),
  }) async {
    final inviteToken = _generateToken();
    final inviteKey = _crypto.deriveInviteKey(inviteToken);

    // Empaquetamos la config de Firebase y la llave de CARTO juntas
    final payload = {
      'transportConfig': transportConfig,
      if (cartoKey != null && cartoKey.isNotEmpty) 'cartoKey': cartoKey,
    };

    final encrypted = await _crypto.encryptWithKeyBytes(
      keyBytes: inviteKey,
      payload: payload,
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

  /// Descifra el payload del QR de join. Devuelve un mapa que contiene
  /// `transportConfig` (Map) y opcionalmente `cartoKey` (String).
  Future<Map<String, dynamic>> decryptInvitePayload(
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
      final decoded = await _crypto.decryptWithKeyBytes(
        keyBytes: inviteKey,
        ciphertextBase64: ct,
        nonceBase64: nonce,
      );
      
      // Si por compatibilidad viene la config "suelta" (sin el wrapper),
      // la envolvemos para que el caller siempre reciba el mismo formato.
      if (!decoded.containsKey('transportConfig')) {
        return {'transportConfig': decoded};
      }
      return decoded;
    } catch (_) {
      throw InviteException('No se pudo descifrar el QR');
    }
  }

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

  String encodeForQr() => jsonEncode(toJson());

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