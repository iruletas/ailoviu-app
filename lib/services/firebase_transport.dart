import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/sync_models.dart';
import 'sync_transport.dart';

class FirebaseTransport implements SyncTransport {
  FirebaseTransport();

  final _incomingController = StreamController<SyncEnvelope>();
  final _statusController = StreamController<TransportStatus>();

  // Stream para que el host reciba las solicitudes del QR
  final _inviteRequestsController = StreamController<InviteRequest>.broadcast();

  FirebaseDatabase? _db;
  String? _deviceId;
  String? _activeInviteToken;
  bool _persistenceOn = false;

  StreamSubscription<DatabaseEvent>? _messagesSub;
  StreamSubscription<DatabaseEvent>? _connectionSub;
  StreamSubscription<DatabaseEvent>? _inviteRequestsSub;
  StreamSubscription<DatabaseEvent>? _inviteChangedSub;

  final Set<String> _emitted = <String>{};

  static const Duration _sendTimeout = Duration(seconds: 8);

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    final deviceId = config['deviceId'] as String?;
    if (deviceId == null) {
      throw ArgumentError('Falta deviceId en transport config');
    }
    _deviceId = deviceId;
    _activeInviteToken = config['activeInviteToken'] as String?;

    final options = FirebaseOptions(
      apiKey: config['apiKey'] as String,
      appId: config['appId'] as String,
      messagingSenderId: config['messagingSenderId'] as String? ?? '',
      projectId: config['projectId'] as String,
      databaseURL: config['databaseUrl'] as String?,
      storageBucket: config['storageBucket'] as String?,
    );

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }

    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        debugPrint('[FirebaseTransport] Error en auth anónima: $e');
      }
    }

    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: config['databaseUrl'] as String?,
    );

    try {
      db.setPersistenceEnabled(true);
    } catch (e) {
      debugPrint('[FirebaseTransport] No se pudo activar persistencia: $e');
    }
    _persistenceOn = true;

    _db = db;

    _statusController.add(TransportStatus.connecting);
    _startWatchingConnection();
    _startListening();
    _startWatchingInvites(); // Arrancamos el escucha de solicitudes
  }

  void _startWatchingConnection() {
    final db = _db;
    if (db == null) return;
    _connectionSub = db.ref('.info/connected').onValue.listen(
      (event) {
        if (_statusController.isClosed) return;
        _statusController.add(
          event.snapshot.value == true
              ? TransportStatus.connected
              : TransportStatus.disconnected,
        );
      },
      onError: (Object e) {
        debugPrint('[FirebaseTransport] Error de conexión: $e');
        if (_statusController.isClosed) return;
        _statusController.add(TransportStatus.error);
      },
    );
  }

  void _startListening() {
    final db = _db;
    final deviceId = _deviceId;
    if (db == null || deviceId == null) return;

    final query = db.ref('inbox/$deviceId/messages').orderByChild('createdAt');
    _messagesSub = query.onChildAdded.listen(
      _onChildAdded,
      onError: (Object e) {
        debugPrint('[FirebaseTransport] Error en inbox: $e');
        if (_statusController.isClosed) return;
        _statusController.add(TransportStatus.error);
      },
    );
  }

  /// Escucha las solicitudes de unión del QR.
  ///
  /// Escucha altas (`onChildAdded`) y cambios (`onChildChanged`): si el
  /// mismo invitado reintenta con el mismo QR, Firebase lo reporta como
  /// cambio, no como alta.
  void _startWatchingInvites() {
    _inviteRequestsSub?.cancel();
    _inviteRequestsSub = null;
    _inviteChangedSub?.cancel();
    _inviteChangedSub = null;

    final db = _db;
    final token = _activeInviteToken;
    if (db == null || token == null || token.isEmpty) return;

    void onEvent(DatabaseEvent event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return;
      try {
        final request =
            InviteRequest.fromJson(Map<String, dynamic>.from(raw));
        if (!_inviteRequestsController.isClosed) {
          _inviteRequestsController.add(request);
        }
      } catch (e) {
        debugPrint('[FirebaseTransport] Error parseando InviteRequest: $e');
      }
    }

    void onError(Object e) {
      debugPrint('[FirebaseTransport] Error escuchando invite requests: $e');
    }

    final ref = db.ref('invites/$token/requests');
    _inviteRequestsSub = ref.onChildAdded.listen(onEvent, onError: onError);
    _inviteChangedSub = ref.onChildChanged.listen(onEvent, onError: onError);
  }

  /// Cambia el token que se escucha (QR nuevo) o deja de escuchar
  /// (`null`). Siempre cancela el listener anterior.
  void updateActiveInviteToken(String? token) {
    if (_activeInviteToken == token) return;
    _activeInviteToken = token;
    _startWatchingInvites();
  }

  Stream<InviteRequest> get inviteRequests => _inviteRequestsController.stream;

  void _onChildAdded(DatabaseEvent event) {
    if (_incomingController.isClosed) return;
    final raw = event.snapshot.value;
    final ref = event.snapshot.ref;

    if (raw is! Map) {
      unawaited(ref.remove().catchError((Object e) {
        debugPrint('[FirebaseTransport] Error limpiando mensaje corrupto: $e');
      }));
      return;
    }

    final SyncEnvelope envelope;
    try {
      envelope = SyncEnvelope.fromJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      debugPrint('[FirebaseTransport] Error parseando SyncEnvelope: $e');
      unawaited(ref.remove().catchError((Object err) {
        debugPrint('[FirebaseTransport] Error limpiando envelope malformado: $err');
      }));
      return;
    }

    if (!_emitted.add(envelope.id)) return;
    _incomingController.add(envelope);
  }

  @override
  Future<void> acknowledge(String envelopeId) async {
    final db = _db;
    final deviceId = _deviceId;
    if (db == null || deviceId == null) return;
    _emitted.remove(envelopeId);
    unawaited(
      db
          .ref('inbox/$deviceId/messages/$envelopeId')
          .remove()
          .catchError((Object e) {
        debugPrint('[FirebaseTransport] Error en acknowledge: $e');
      }),
    );
  }

  @override
  Future<TransportResult> send(SyncEnvelope envelope) async {
    final db = _db;
    if (db == null) {
      return const TransportResult(
        accepted: false,
        error: 'Transporte no inicializado',
      );
    }

    try {
      await db
          .ref('inbox/${envelope.to}/messages/${envelope.id}')
          .set(envelope.toJson())
          .timeout(_sendTimeout);
      return TransportResult.ok;
    } on TimeoutException {
      if (_persistenceOn) {
        return const TransportResult(accepted: true);
      }
      return const TransportResult(
        accepted: false,
        error: 'Sin conexión',
      );
    } catch (e) {
      debugPrint('[FirebaseTransport] Error en send: $e');
      return TransportResult(accepted: false, error: e.toString());
    }
  }

  // ── Buzón público de invites ────────────────────────────────────

  Future<bool> publishInviteRequest({
    required String inviteToken,
    required InviteRequest request,
  }) async {
    final db = _db;
    if (db == null) return false;
    try {
      await db
          .ref('invites/$inviteToken/requests/${request.guestDeviceId}')
          .set(request.toJson())
          .timeout(_sendTimeout);
      return true;
    } catch (e) {
      debugPrint('[FirebaseTransport] Error publicando invite: $e');
      return false;
    }
  }

  Future<void> clearInvite(String inviteToken) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.ref('invites/$inviteToken').remove();
    } catch (e) {
      debugPrint('[FirebaseTransport] Error limpiando invite: $e');
    }
  }

  Future<void> sweepExpiredInvites({
    required Duration maxAge,
  }) async {
    final db = _db;
    if (db == null) return;
    try {
      final snapshot = await db.ref('invites').get();
      if (!snapshot.exists) return;
      final raw = snapshot.value;
      if (raw is! Map) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in raw.entries) {
        final token = entry.key as String;
        final node = entry.value;
        if (node is! Map) continue;
        final requests = node['requests'];
        if (requests is! Map) continue;
        var allOld = true;
        for (final r in requests.values) {
          if (r is! Map) continue;
          final ts = r['createdAt'] as int?;
          if (ts == null) continue;
          if (now - ts < maxAge.inMilliseconds) {
            allOld = false;
            break;
          }
        }
        if (allOld) {
          await db.ref('invites/$token').remove();
        }
      }
    } catch (e) {
      debugPrint('[FirebaseTransport] Error en sweepInvites: $e');
    }
  }

  @override
  Stream<SyncEnvelope> get incoming => _incomingController.stream;

  @override
  Stream<TransportStatus> get status => _statusController.stream;

  @override
  Future<void> dispose() async {
    await _messagesSub?.cancel();
    await _connectionSub?.cancel();
    await _inviteRequestsSub?.cancel();
    await _inviteChangedSub?.cancel();
    _inviteChangedSub = null;
    _messagesSub = null;
    _connectionSub = null;
    _inviteRequestsSub = null;
    unawaited(_incomingController.close());
    unawaited(_statusController.close());
    unawaited(_inviteRequestsController.close());
    _emitted.clear();
    _db = null;
  }
}