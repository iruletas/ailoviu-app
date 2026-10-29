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

/// Orquestador de sync.
///
/// - Encola sobres para envío.
/// - Escucha sobres entrantes, los descifra, y los emite.
/// - Maneja la reconexión.
/// - No sabe de transportes concretos (habla con [SyncTransport]).
/// - No sabe de criptografía concreta (habla con [CryptoService]).
///
/// Entrega de sobres entrantes:
/// 1. Se procesan de uno en uno y en orden.
/// 2. Un sobre solo se confirma al transporte (y se borra del buzón)
///    cuando se entregó a alguien que escucha [events]. Si nadie
///    escucha todavía, espera en una cola en memoria Y sigue en el
///    buzón: si la app se cierra, se reentrega al volver.
/// 3. Los sobres inválidos, expirados o ilegibles se descartan: no
///    tienen arreglo y atascarían el buzón.
/// 4. Se deduplica por id (el transporte puede reentregar).
///
/// Modo [notifyOnly] (servicio en segundo plano): solo descifra y
/// notifica. NUNCA entrega ni confirma, así el sobre sigue en el
/// buzón hasta que la app lo procese.
///
/// Ojo: cuando existan las features que persisten mensajes (Bloque
/// C), lo ideal es confirmar después de persistir, no al entregar.
class SyncService {
  SyncService({
    required KeyStore keyStore,
    required CryptoService crypto,
    required NotificationService notifications,
    this.notifyOnly = false,
  })  : _keyStore = keyStore,
        _crypto = crypto,
        _notifications = notifications;

  /// `true` en el servicio en segundo plano: solo notifica.
  final bool notifyOnly;

  final KeyStore _keyStore;
  final CryptoService _crypto;
  final NotificationService _notifications;

  final _uuid = const Uuid();

  late final StreamController<SyncEvent> _eventsController =
      StreamController<SyncEvent>.broadcast(onListen: _onFirstListener);
  final _statusController = StreamController<SyncStatus>.broadcast();

  /// Eventos que llegaron cuando nadie escuchaba [events].
  final List<SyncEvent> _pending = <SyncEvent>[];
  static const int _maxPending = 500;

  /// ids ya procesados (los más recientes). Orden de inserción.
  final Set<String> _seen = <String>{};
  static const int _maxSeen = 500;

  SyncTransport? _transport;
  StreamSubscription<void>? _incomingSub;
  StreamSubscription<TransportStatus>? _statusSub;

  Uint8List? _sharedSecret;
  String? _deviceId;
  String? _peerDeviceId;

  SyncStatus _status = SyncStatus.unpaired;

  Stream<SyncEvent> get events => _eventsController.stream;
  Stream<SyncStatus> get status => _statusController.stream;
  SyncStatus get currentStatus => _status;

  /// Inicializa el servicio.
  Future<void> initialize() async {
    try {
      await _notifications.initialize(requestPermission: !notifyOnly);
    } catch (_) {
      // Sin notificaciones el sync debe funcionar igual.
    }

    _deviceId = await _keyStore.getDeviceId();
    if (_deviceId == null) {
      _deviceId = _uuid.v4();
      await _keyStore.setDeviceId(_deviceId!);
    }

    _peerDeviceId = await _keyStore.getPeerDeviceId();
    final secret = await _keyStore.getSharedSecret();
    if (secret != null) {
      _sharedSecret = Uint8List.fromList(base64Decode(secret));
    }

    if (_peerDeviceId == null || _sharedSecret == null) {
      _setStatus(SyncStatus.unpaired);
      return;
    }

    final config = await TransportConfig.load(_keyStore);
    if (!config.isConfigured) {
      _setStatus(SyncStatus.offline);
      return;
    }

    await _initializeTransport(config);
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

      // Los streams del transporte son de una sola suscripción y
      // bufferean: lo que llegó durante initialize() se entrega aquí.
      // asyncMap procesa un sobre a la vez, en orden.
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

  /// Encola un payload para envío. Devuelve el id del sobre.
  ///
  /// Lanza [StateError] si no hay sync listo o si el transporte
  /// rechazó el envío, para que quien llama pueda reintentar o avisar.
  Future<String> enqueue({
    required SyncType type,
    required Map<String, dynamic> payload,
    String? replyTo,
    int? ttlMs,
  }) async {
    final transport = _transport;
    final secret = _sharedSecret;
    final deviceId = _deviceId;
    final peerDeviceId = _peerDeviceId;

    if (transport == null ||
        secret == null ||
        deviceId == null ||
        peerDeviceId == null) {
      throw StateError('Sync no inicializado o pareja no emparejada');
    }

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
      to: peerDeviceId,
      type: type.name,
      createdAt: createdAt.toString(),
      nonce: encrypted.nonceBase64,
      ciphertext: encrypted.ciphertextBase64,
    );

    final envelope = SyncEnvelope(
      v: 1,
      id: id,
      from: deviceId,
      to: peerDeviceId,
      type: type,
      createdAt: createdAt,
      ttlMs: ttlMs,
      nonce: encrypted.nonceBase64,
      ciphertext: encrypted.ciphertextBase64,
      signature: signature,
      replyTo: replyTo,
    );

    final result = await transport.send(envelope);
    if (!result.accepted) {
      throw StateError(
        'No se pudo enviar el sobre: ${result.error ?? 'error desconocido'}',
      );
    }
    return id;
  }

  /// Pide un sync completo al otro dispositivo.
  Future<void> requestFullSync() async {
    await enqueue(
      type: SyncType.syncRequest,
      payload: {'requestedAt': DateTime.now().toIso8601String()},
    );
  }

  // ── Recepción ───────────────────────────────────────────────────

  Future<void> _handleIncoming(SyncEnvelope envelope) async {
    final transport = _transport;
    final secret = _sharedSecret;
    if (transport == null || secret == null) return;

    try {
      // Reentrega de algo ya procesado: solo confirmar.
      if (_seen.contains(envelope.id)) {
        if (!notifyOnly) _ack(envelope.id);
        return;
      }

      final event = await _decode(envelope, secret);
      if (event == null) {
        // Inválido, expirado o ilegible: no tiene arreglo. Se
        // descarta para no atascar el buzón.
        if (!notifyOnly) _ack(envelope.id);
        return;
      }

      _markSeen(envelope.id);
      if (!notifyOnly) _deliver(event);
      await _notifyIfNeeded(event);
    } catch (_) {
      // Fallo inesperado: NO se confirma, el sobre sigue en el buzón.
    }
  }

  /// Verifica, revisa TTL y descifra. `null` = descartar.
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

  /// Entrega el evento a quien escuche, o lo deja en la cola interna
  /// hasta que alguien escuche. El sobre se confirma al transporte
  /// solo cuando un suscriptor lo recibe ([_emit]).
  void _deliver(SyncEvent event) {
    if (_eventsController.isClosed) return;

    if (_eventsController.hasListener) {
      _flushPending(); // primero lo acumulado, para conservar el orden
      _emit(event);
      return;
    }

    // Si la cola está llena, el sobre simplemente se queda en el
    // buzón (sin confirmar) y se reentrega en el próximo arranque.
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
    // Microtask: asegura que la suscripción ya quedó registrada.
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
    if (_seen.length > _maxSeen) {
      _seen.remove(_seen.first);
    }
  }

  Future<void> _notifyIfNeeded(SyncEvent event) async {
    final type = event.envelope.type;
    if (type != SyncType.message && type != SyncType.state) return;
    try {
      final title =
          type == SyncType.message ? 'Nuevo mensaje' : 'Nuevo estado';
      final body = event.payload.data['preview'] as String? ?? 'Toca para ver';
      // Id derivado del sobre: si la app y el servicio en segundo
      // plano notifican lo mismo, se reemplazan en vez de duplicarse.
      await _notifications.show(
        title: title,
        body: body,
        id: NotificationService.stableId(event.envelope.id),
      );
    } catch (_) {
      // Una notificación fallida no debe afectar la entrega.
    }
  }

  void _setStatus(SyncStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Cierra el servicio.
  Future<void> dispose() async {
    await _incomingSub?.cancel();
    await _statusSub?.cancel();
    await _transport?.dispose();
    _pending.clear();
    await _eventsController.close();
    await _statusController.close();
  }
}
