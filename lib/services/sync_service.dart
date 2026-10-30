import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../models/sync_models.dart';
import 'crypto_service.dart';
import 'firebase_transport.dart';
import 'key_store.dart';
import 'notification_service.dart';
import 'sync_transport.dart';
import 'transport_config.dart';

/// Orquestador de sync multi-miembro.
///
/// Mantiene un `sharedSecret` por cada peer aprobado. `enqueue`
/// acepta `to` explícito o manda a todos si no se especifica.
///
/// El contrato de entrega (dedup, ACK, notifyOnly) no cambia.
class SyncService {
  SyncService({
    required KeyStore keyStore,
    required CryptoService crypto,
    required NotificationService notifications,
    this.notifyOnly = false,
  })  : _keyStore = keyStore,
        _crypto = crypto,
        _notifications = notifications;

  final bool notifyOnly;

  final KeyStore _keyStore;
  final CryptoService _crypto;
  final NotificationService _notifications;

  final _uuid = const Uuid();

  late final StreamController<SyncEvent> _eventsController =
      StreamController<SyncEvent>.broadcast(onListen: _onFirstListener);
  final _statusController = StreamController<SyncStatus>.broadcast();

  final List<SyncEvent> _pending = <SyncEvent>[];
  static const int _maxPending = 500;

  final Set<String> _seen = <String>{};
  static const int _maxSeen = 500;

  SyncTransport? _transport;
  StreamSubscription<void>? _incomingSub;
  StreamSubscription<TransportStatus>? _statusSub;

  final Map<String, Uint8List> _sharedSecrets = {};

  String? _deviceId;

  SyncStatus _status = SyncStatus.unpaired;

  Stream<SyncEvent> get events => _eventsController.stream;
  Stream<SyncStatus> get status => _statusController.stream;
  SyncStatus get currentStatus => _status;

  bool get hasPeers => _sharedSecrets.isNotEmpty;

  Future<void> initialize() async {
    try {
      await _notifications.initialize(requestPermission: !notifyOnly);
    } catch (_) {}

    _deviceId = await _keyStore.getDeviceId();
    if (_deviceId == null) {
      _deviceId = _uuid.v4();
      await _keyStore.setDeviceId(_deviceId!);
    }

    await reloadPeers();
  }

  /// Vuelve a leer los secrets de peers y reinicializa el transporte
  /// si hace falta. Se llama cuando entra o sale un miembro.
  Future<void> reloadPeers() async {
    final members = await _keyStore.getGroupMembers();
    _sharedSecrets.clear();
    for (final m in members.values) {
      if (m.deviceId == _deviceId) continue;
      if (!m.approved) continue;
      final secretB64 = await _keyStore.getPeerSharedSecret(m.deviceId);
      if (secretB64 == null) continue;
      try {
        _sharedSecrets[m.deviceId] =
            Uint8List.fromList(base64Decode(secretB64));
      } catch (_) {}
    }

    if (_sharedSecrets.isEmpty) {
      _setStatus(SyncStatus.unpaired);
      return;
    }

    final config = await TransportConfig.load(_keyStore);
    if (!config.isConfigured) {
      _setStatus(SyncStatus.offline);
      return;
    }

    if (_transport == null) {
      await _initializeTransport(config);
    }
  }

  Future<void> _initializeTransport(TransportConfig config) async {
    if (config is FirebaseTransportConfig) {
      _transport = FirebaseTransport();
    } else {
      _setStatus(SyncStatus.offline);
      return;
    }

    try {
      await _transport!.initialize({
        'deviceId': _deviceId,
        ...config.toJson(),
      });

      _incomingSub = _transport!.incoming
          .asyncMap<void>(_handleIncoming)
          .listen((_) {});

      _statusSub = _transport!.status.listen((s) {
        switch (s) {
          case TransportStatus.connected:
            _setStatus(SyncStatus.online);
            break;
          case TransportStatus.connecting:
            _setStatus(SyncStatus.syncing);
            break;
          case TransportStatus.disconnected:
            _setStatus(SyncStatus.offline);
            break;
          case TransportStatus.error:
            _setStatus(SyncStatus.error);
            break;
        }
      });
    } catch (_) {
      _setStatus(SyncStatus.error);
    }
  }

  /// Encola un payload. `to == null` = a todos los peers.
  /// Devuelve los ids de los sobres enviados.
  Future<List<String>> enqueue({
    required SyncType type,
    required Map<String, dynamic> payload,
    String? to,
    String? replyTo,
    int? ttlMs,
  }) async {
    final transport = _transport;
    final deviceId = _deviceId;
    if (transport == null || deviceId == null) {
      throw StateError('Sync no inicializado');
    }

    final targets = to != null
        ? [to]
        : _sharedSecrets.keys.toList(growable: false);
    if (targets.isEmpty) return [];

    final sentIds = <String>[];
    for (final peerId in targets) {
      final secret = _sharedSecrets[peerId];
      if (secret == null) continue;

      final id = _uuid.v4();
      final createdAt = DateTime.now().millisecondsSinceEpoch;
      final encrypted = await _crypto.encrypt(
        sharedSecret: secret,
        payload: payload,
      );
      final signature = _crypto.signEnvelope(
        sharedSecret: secret,
        v: '1',
        id: id,
        from: deviceId,
        to: peerId,
        type: type.name,
        createdAt: createdAt.toString(),
        nonce: encrypted.nonceBase64,
        ciphertext: encrypted.ciphertextBase64,
      );

      final envelope = SyncEnvelope(
        v: 1,
        id: id,
        from: deviceId,
        to: peerId,
        type: type,
        createdAt: createdAt,
        ttlMs: ttlMs,
        nonce: encrypted.nonceBase64,
        ciphertext: encrypted.ciphertextBase64,
        signature: signature,
        replyTo: replyTo,
      );

      final result = await transport.send(envelope);
      if (result.accepted) sentIds.add(id);
    }
    return sentIds;
  }

  /// Publica una solicitud de join en el buzón público del inviteToken.
  /// El guest lo llama después de `prepareJoin`. Devuelve true si se
  /// publicó (no garantiza que el host lo lea).
  Future<bool> publishInvite({
    required String inviteToken,
    required InviteRequest request,
  }) async {
    final transport = _transport;
    if (transport is FirebaseTransport) {
      return transport.publishInviteRequest(
        inviteToken: inviteToken,
        request: request,
      );
    }
    // Fallback: si no hay transport inicializado todavía, intentamos
    // inicializar uno a partir del transport config (el guest ya lo
    // tiene en Keystore después de prepareJoin).
    final config = await TransportConfig.load(_keyStore);
    if (config is! FirebaseTransportConfig) return false;
    final tempTransport = FirebaseTransport();
    try {
      await tempTransport.initialize({
        'deviceId': _deviceId,
        ...config.toJson(),
      });
      final ok = await tempTransport.publishInviteRequest(
        inviteToken: inviteToken,
        request: request,
      );
      await tempTransport.dispose();
      return ok;
    } catch (_) {
      await tempTransport.dispose();
      return false;
    }
  }

  /// Publica una solicitud de recuperación en el mismo buzón.
  /// Idéntico a publishInvite pero semánticamente distinto.
  Future<bool> publishRecovery({
    required String inviteToken,
    required InviteRequest request,
  }) => publishInvite(inviteToken: inviteToken, request: request);

  Future<void> requestFullSync() async {
    await enqueue(
      type: SyncType.syncRequest,
      payload: {'requestedAt': DateTime.now().toIso8601String()},
    );
  }

  Future<void> _handleIncoming(SyncEnvelope envelope) async {
    final transport = _transport;
    if (transport == null) return;

    try {
      if (_seen.contains(envelope.id)) {
        if (!notifyOnly) _ack(envelope.id);
        return;
      }

      final secret = _sharedSecrets[envelope.from];
      if (secret == null) {
        if (!notifyOnly) _ack(envelope.id);
        return;
      }

      final event = await _decode(envelope, secret);
      if (event == null) {
        if (!notifyOnly) _ack(envelope.id);
        return;
      }

      _markSeen(envelope.id);
      if (!notifyOnly) _deliver(event);
      await _notifyIfNeeded(event);
    } catch (_) {}
  }

  Future<SyncEvent?> _decode(
    SyncEnvelope envelope,
    Uint8List secret,
  ) async {
    try {
      final valid = _crypto.verifyEnvelope(
        sharedSecret: secret,
        v: envelope.v.toString(),
        id: envelope.id,
        from: envelope.from,
        to: envelope.to,
        type: envelope.type.name,
        createdAt: envelope.createdAt.toString(),
        nonce: envelope.nonce,
        ciphertext: envelope.ciphertext,
        signature: envelope.signature,
      );
      if (!valid) return null;
      if (envelope.isExpired()) return null;

      final payload = await _crypto.decrypt(
        sharedSecret: secret,
        ciphertextBase64: envelope.ciphertext,
        nonceBase64: envelope.nonce,
      );

      return SyncEvent(
        envelope: envelope,
        payload: SyncPayload(
          type: envelope.type,
          data: payload,
          replyTo: envelope.replyTo,
          receivedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  void _deliver(SyncEvent event) {
    if (_eventsController.isClosed) return;
    if (_eventsController.hasListener) {
      _flushPending();
      _emit(event);
      return;
    }
    if (_pending.length < _maxPending) _pending.add(event);
  }

  void _emit(SyncEvent event) {
    _eventsController.add(event);
    _ack(event.envelope.id);
  }

  void _ack(String envelopeId) {
    final transport = _transport;
    if (transport == null) return;
    unawaited(transport.acknowledge(envelopeId));
  }

  void _onFirstListener() {
    scheduleMicrotask(_flushPending);
  }

  void _flushPending() {
    while (_pending.isNotEmpty &&
        !_eventsController.isClosed &&
        _eventsController.hasListener) {
      _emit(_pending.removeAt(0));
    }
  }

  void _markSeen(String id) {
    _seen.add(id);
    if (_seen.length > _maxSeen) _seen.remove(_seen.first);
  }

  Future<void> _notifyIfNeeded(SyncEvent event) async {
    final type = event.envelope.type;
    if (type != SyncType.message &&
        type != SyncType.state &&
        type != SyncType.memberJoin &&
        type != SyncType.memberLeave &&
        type != SyncType.joinRequest &&
        type != SyncType.recoveryRequest &&
        type != SyncType.memberAccept) {
      return;
    }
    try {
      final (title, body) = _notificationCopyFor(event);
      await _notifications.show(
        title: title,
        body: body,
        id: NotificationService.stableId(event.envelope.id),
      );
    } catch (_) {}
  }

  (String, String) _notificationCopyFor(SyncEvent event) {
    final d = event.payload.data;
    switch (event.envelope.type) {
      case SyncType.message:
        final intent = d['intent'] as String?;
        if (intent == 'buzz') {
          return ('⚡ Zumbido', d['preview'] as String? ?? 'Te mandó un zumbido');
        }
        return ('Nuevo mensaje', d['preview'] as String? ?? 'Toca para ver');
      case SyncType.state:
        final sub = d['subtype'] as String?;
        if (sub == 'status') {
          final s = d['status'] as Map?;
          final text = s?['text'] as String? ?? '';
          return ('💭 Actualizó su estado', text);
        }
        if (sub == 'location') {
          return ('📍 Nueva ubicación', 'Toca para ver en el mapa');
        }
        return ('Nuevo estado', d['preview'] as String? ?? '');
      case SyncType.memberJoin:
        final m = d['member'] as Map?;
        final name = m?['displayName'] as String? ?? 'Alguien';
        return ('👤 Nuevo integrante', '$name se unió al grupo');
      case SyncType.memberLeave:
        return ('👋 Salió un integrante', 'Alguien salió del grupo');
      case SyncType.joinRequest:
        final name = d['displayName'] as String? ?? 'Alguien';
        return ('👤 Quiere unirse', '$name quiere unirse. Toca para aprobar');
      case SyncType.recoveryRequest:
        final name = d['displayName'] as String? ?? 'Alguien';
        return ('🔄 Recuperación', '$name quiere recuperar su cuenta');
      case SyncType.memberAccept:
        return ('✅ Bienvenido', 'Ya eres parte del grupo');
      default:
        return ('Ailoviu', '');
    }
  }

  void _setStatus(SyncStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  Future<void> dispose() async {
    await _incomingSub?.cancel();
    await _statusSub?.cancel();
    await _transport?.dispose();
    _pending.clear();
    await _eventsController.close();
    await _statusController.close();
  }
}