import 'package:flutter/foundation.dart';

/// Tipos de sobre que viajan entre dispositivos.
///
/// Enum cerrado a propósito: agregar un tipo nuevo es agregar un valor
/// aquí. Clientes viejos ignoran tipos que no conocen.
enum SyncType {
  /// Mensajes de texto, Cartas, Diario (entrada individual).
  message,

  /// Estado privado ("cómo me siento ahora"), estado de relación.
  state,

  /// Referencia a una foto o archivo en Firebase Storage + metadatos.
  photoRef,

  /// Confirmación de descarga de foto. El remitente borra el blob.
  photoAck,

  /// Movimiento de juego a distancia.
  gameMove,

  /// Estado completo de juego a distancia (para resync).
  gameState,

  /// Presencia: online, escribiendo, offline.
  presence,

  /// Intercambio de claves (solo en emparejamiento, no en sync normal).
  keyExchange,

  /// Petición de sync completo cuando se reconecta.
  syncRequest,

  /// Confirmación de sync completo.
  syncAck,
}

/// Sobre cifrado. Es lo único que viaja entre dispositivos.
///
/// El contenido real va en [ciphertext], cifrado con Signal Protocol.
/// Todo lo demás es routing y verificación.
@immutable
class SyncEnvelope {
  /// Versión del formato. Empieza en 1. Permite migrar sin romper
  /// clientes viejos.
  final int v;

  /// ULID local, único por sobre. Sirve para deduplicar.
  final String id;

  /// deviceId del remitente.
  final String from;

  /// deviceId del destinatario.
  final String to;

  final SyncType type;

  /// Epoch ms del remitente. Sirve para ordenar y para TTL.
  final int createdAt;

  /// Si expira, el receptor descarta el sobre.
  final int? ttlMs;

  /// Base64, 12 bytes, único por sobre. Nunca reutilizar con la misma
  /// clave.
  final String nonce;

  /// Base64. Payload cifrado con Signal Protocol (AES-GCM).
  final String ciphertext;

  /// Base64. HMAC-SHA256 del sobre (cubre v, id, from, to, type,
  /// createdAt, nonce, ciphertext). Verifica integridad y
  /// autenticidad.
  final String signature;

  /// id del sobre al que responde, si aplica (conversaciones).
  final String? replyTo;

  /// Metadatos NO sensibles. Solo routing: topic, chunkIndex,
  /// totalChunks, hash del blob, etc. Nunca contenido.
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

  /// `true` si el sobre expiró según [ttlMs].
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
  /// No hay pareja emparejada. App local-only.
  unpaired,

  /// Hay pareja, pero el transporte no está conectado.
  offline,

  /// Conectado, escuchando.
  online,

  /// En medio de un envío o recepción.
  syncing,

  /// Error de transporte o de criptografía.
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