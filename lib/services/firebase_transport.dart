import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/sync_models.dart';
import 'sync_transport.dart';

/// Transporte sobre Firebase Realtime Database.
///
/// Además del inbox privado (que ya existía), este transporte
/// soporta el buzón público `invites/{token}` para el primer
/// contacto del guest antes de tener el grupo configurado.
class FirebaseTransport implements SyncTransport {
  FirebaseTransport();

  final _incomingController = StreamController<SyncEnvelope>();
  final _statusController = StreamController<TransportStatus>();

  FirebaseDatabase? _db;
  String? _deviceId;
  bool _persistenceOn = false;

  StreamSubscription<DatabaseEvent>? _messagesSub;
  StreamSubscription<DatabaseEvent>? _connectionSub;

  final Set<String> _emitted = <String>{};

  static const Duration _sendTimeout = Duration(seconds: 8);

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    final deviceId = config['deviceId'] as String?;
    if (deviceId == null) {
      throw ArgumentError('Falta deviceId en transport config');
    }
    _deviceId = deviceId;

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

    // Anónimo: el guest necesita auth para escribir en invites/{token}.
    // El host también, pero ya está autenticado por el mismo flujo.
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (_) {
        // Sin auth el inbox privado igual funciona (reglas: auth != null).
        // El buzón público de invites va a fallar. Es aceptable si el
        // guest ya está vinculado.
      }
    }

    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: config['databaseUrl'] as String?,
    );

    try {
      db.setPersistenceEnabled(true);
    } catch (_) {}
    _persistenceOn = true;

    _db = db;

    _statusController.add(TransportStatus.connecting);
    _startWatchingConnection();
    _startListening();
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
      onError: (Object _) {
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
      onError: (Object _) {
        if (_statusController.isClosed) return;
        _statusController.add(TransportStatus.error);
      },
    );
  }

  void _onChildAdded(DatabaseEvent event) {
    if (_incomingController.isClosed) return;
    final raw = event.snapshot.value;
    final ref = event.snapshot.ref;

    if (raw is! Map) {
      unawaited(ref.remove().catchError((Object _) {}));
      return;
    }

    final SyncEnvelope envelope;
    try {
      envelope = SyncEnvelope.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      unawaited(ref.remove().catchError((Object _) {}));
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
          .catchError((Object _) {}),
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
      return TransportResult(accepted: false, error: e.toString());
    }
  }

  // ── Buzón público de invites ────────────────────────────────────
  //
  // A diferencia del inbox privado, este buzón no está cifrado por
  // par (todavía no hay par). El guest escribe su solicitud con el
  // proof calculado a partir del inviteToken. El host lo lee y lo
  // valida.

  /// El guest publica su solicitud en `invites/{token}/requests/{deviceId}`.
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
    } catch (_) {
      return false;
    }
  }

  /// El host escucha las solicitudes entrantes para un inviteToken.
  Stream<InviteRequest> watchInviteRequests(String inviteToken) {
    final db = _db;
    if (db == null) return const Stream.empty();
    final ref = db.ref('invites/$inviteToken/requests');
    return ref.onChildAdded.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) throw StateError('Solicitud malformada');
      return InviteRequest.fromJson(Map<String, dynamic>.from(raw));
    });
  }

  /// El host borra el buzón completo cuando ya procesó todas las
  /// solicitudes (o cuando expira el QR).
  Future<void> clearInvite(String inviteToken) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.ref('invites/$inviteToken').remove();
    } catch (_) {}
  }

  /// Barrido de invites huérfanos: el host limpia los que ya
  /// expiraron. Se llama al arrancar la app.
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
    } catch (_) {}
  }

  @override
  Stream<SyncEnvelope> get incoming => _incomingController.stream;

  @override
  Stream<TransportStatus> get status => _statusController.stream;

  @override
  Future<void> dispose() async {
    await _messagesSub?.cancel();
    await _connectionSub?.cancel();
    _messagesSub = null;
    _connectionSub = null;
    unawaited(_incomingController.close());
    unawaited(_statusController.close());
    _emitted.clear();
    _db = null;
  }
}