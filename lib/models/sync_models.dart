import 'package:flutter/foundation.dart';

/// Tipos de sobre que viajan entre dispositivos.
enum SyncType {
  message,
  state,
  photoRef,
  photoAck,
  gameMove,
  gameState,
  presence,
  keyExchange,
  syncRequest,
  syncAck,

  /// Un miembro nuevo fue aprobado y se anuncia al grupo.
  memberJoin,

  /// Alguien salió o fue expulsado.
  memberLeave,

  /// El host comparte credenciales de Firebase a un miembro nuevo.
  hostCredentials,

  /// El guest pide al host (o a todos los miembros) que lo aprueben.
  joinRequest,

  /// Un miembro existente aprueba o rechaza un join/recovery.
  joinVote,

  /// El host confirma al guest que fue aceptado, con la lista de
  /// miembros y la confirmación de credenciales.
  memberAccept,

  /// Un miembro rechazó el join.
  memberReject,

  /// Alguien pide recuperar su cuenta desde un dispositivo nuevo.
  recoveryRequest,

  /// Un miembro vota en una solicitud de recuperación.
  recoveryVote,

  /// El host confirma la recuperación: el miembro viejo se da de
  /// baja y el nuevo ocupa su lugar.
  recoveryAccept,

  /// Alguien cambió su PIN de recuperación. Los demás actualizan su
  /// copia local del hash.
  recoveryPinUpdate,

  /// El host comparte o actualiza la pregunta de recuperación del
  /// grupo.
  recoveryQuestionUpdate,
}

/// Sobre cifrado. Es lo único que viaja entre dispositivos.
@immutable
class SyncEnvelope {
  final int v;
  final String id;
  final String from;
  final String to;
  final SyncType type;
  final int createdAt;
  final int? ttlMs;
  final String nonce;
  final String ciphertext;
  final String signature;
  final String? replyTo;
  final Map<String, String>? meta;

  const SyncEnvelope({
    required this.v,
    required this.id,
    required this.from,
    required this.to,
    required this.type,
    required this.createdAt,
    required this.nonce,
    required this.ciphertext,
    required this.signature,
    this.ttlMs,
    this.replyTo,
    this.meta,
  });

  Map<String, dynamic> toJson() => {
        'v': v,
        'id': id,
        'from': from,
        'to': to,
        'type': type.name,
        'createdAt': createdAt,
        if (ttlMs != null) 'ttlMs': ttlMs,
        'nonce': nonce,
        'ciphertext': ciphertext,
        'signature': signature,
        if (replyTo != null) 'replyTo': replyTo,
        if (meta != null) 'meta': meta,
      };

  static SyncEnvelope fromJson(Map<String, dynamic> json) => SyncEnvelope(
        v: json['v'] as int,
        id: json['id'] as String,
        from: json['from'] as String,
        to: json['to'] as String,
        type: SyncType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => SyncType.message,
        ),
        createdAt: json['createdAt'] as int,
        ttlMs: json['ttlMs'] as int?,
        nonce: json['nonce'] as String,
        ciphertext: json['ciphertext'] as String,
        signature: json['signature'] as String,
        replyTo: json['replyTo'] as String?,
        meta: (json['meta'] as Map?)?.cast<String, String>(),
      );

  bool isExpired({DateTime? now}) {
    if (ttlMs == null) return false;
    final current = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return current > createdAt + ttlMs!;
  }
}

/// Payload descifrado de un sobre entrante.
@immutable
class SyncPayload {
  final SyncType type;
  final Map<String, dynamic> data;
  final String? replyTo;
  final DateTime receivedAt;

  const SyncPayload({
    required this.type,
    required this.data,
    required this.receivedAt,
    this.replyTo,
  });
}

/// Evento emitido por SyncService cuando llega un sobre.
@immutable
class SyncEvent {
  final SyncEnvelope envelope;
  final SyncPayload payload;

  const SyncEvent({required this.envelope, required this.payload});
}

/// Estado del servicio de sync.
enum SyncStatus {
  unpaired,
  offline,
  online,
  syncing,
  error,
}

/// Resultado de un envío por transporte.
@immutable
class TransportResult {
  final bool accepted;
  final String? remoteId;
  final String? error;

  const TransportResult({
    required this.accepted,
    this.remoteId,
    this.error,
  });

  static const TransportResult ok = TransportResult(accepted: true);
}

/// Estado del transporte.
enum TransportStatus { disconnected, connecting, connected, error }

/// Contenido del buzón público `invites/{token}`.
///
/// Es lo único que el guest publica antes de tener el transport
/// configurado. El host lo lee con las credenciales del grupo.
@immutable
class InviteRequest {
  final String groupId;
  final String guestDeviceId;
  final String guestPublicKeyBase64;
  final String displayName;
  final String proof;
  final int createdAt;
  final String? recoveryPinHash;
  final String? recoveryOldDeviceId;

  const InviteRequest({
    required this.groupId,
    required this.guestDeviceId,
    required this.guestPublicKeyBase64,
    required this.displayName,
    required this.proof,
    required this.createdAt,
    this.recoveryPinHash,
    this.recoveryOldDeviceId,
  });

  bool get isRecovery => recoveryOldDeviceId != null;

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'guestDeviceId': guestDeviceId,
        'guestPublicKeyBase64': guestPublicKeyBase64,
        'displayName': displayName,
        'proof': proof,
        'createdAt': createdAt,
        if (recoveryPinHash != null) 'recoveryPinHash': recoveryPinHash,
        if (recoveryOldDeviceId != null)
          'recoveryOldDeviceId': recoveryOldDeviceId,
      };

  static InviteRequest fromJson(Map<String, dynamic> json) => InviteRequest(
        groupId: json['groupId'] as String,
        guestDeviceId: json['guestDeviceId'] as String,
        guestPublicKeyBase64: json['guestPublicKeyBase64'] as String,
        displayName: json['displayName'] as String,
        proof: json['proof'] as String,
        createdAt: json['createdAt'] as int,
        recoveryPinHash: json['recoveryPinHash'] as String?,
        recoveryOldDeviceId: json['recoveryOldDeviceId'] as String?,
      );
}