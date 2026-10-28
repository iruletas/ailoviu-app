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
class SyncService {
  SyncService({
    required KeyStore keyStore,
    required CryptoService crypto,
    required NotificationService notifications,
  })  : _keyStore = keyStore,
        _crypto = crypto,
        _notifications = notifications;

  final KeyStore _keyStore;
  final CryptoService _crypto;
  final NotificationService _notifications;

  final _uuid = const Uuid();
  final _eventsController = StreamController<SyncEvent>.broadcast();
  final _statusController = StreamController<SyncStatus>.broadcast();

  SyncTransport? _transport;
  StreamSubscription<SyncEnvelope>? _incomingSub;
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
      _incomingSub = _transport!.incoming.listen(_handleIncoming);
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

    await transport.send(envelope);
    return id;
  }

  /// Pide un sync completo al otro dispositivo.
  Future<void> requestFullSync() async {
    await enqueue(
      type: SyncType.syncRequest,
      payload: {'requestedAt': DateTime.now().toIso8601String()},
    );
  }

  Future<void> _handleIncoming(SyncEnvelope envelope) async {
    final secret = _sharedSecret;
    if (secret == null) return;

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
    if (!valid) return;

    if (envelope.isExpired()) return;

    Map<String, dynamic> payload;
    try {
      payload = await _crypto.decrypt(
        sharedSecret: secret,
        ciphertextBase64: envelope.ciphertext,
        nonceBase64: envelope.nonce,
      );
    } on CryptoException {
      return;
    }

    final syncPayload = SyncPayload(
      type: envelope.type,
      data: payload,
      replyTo: envelope.replyTo,
      receivedAt: DateTime.now(),
    );

    _eventsController.add(
      SyncEvent(envelope: envelope, payload: syncPayload),
    );

    if (envelope.type == SyncType.message ||
        envelope.type == SyncType.state) {
      final title = envelope.type == SyncType.message
          ? 'Nuevo mensaje'
          : 'Nuevo estado';
      final body = payload['preview'] as String? ?? 'Toca para ver';
      await _notifications.show(title: title, body: body);
    }
  }

  void _setStatus(SyncStatus status) {
    if (_status == status) return;
    _status = status;
    _statusController.add(status);
  }

  /// Cierra el servicio.
  Future<void> dispose() async {
    await _incomingSub?.cancel();
    await _statusSub?.cancel();
    await _transport?.dispose();
    await _eventsController.close();
    await _statusController.close();
  }
}