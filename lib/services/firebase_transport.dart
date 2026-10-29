import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/sync_models.dart';
import 'sync_transport.dart';

/// Transporte sobre Firebase Realtime Database.
///
/// - `send`: escribe el sobre en `inbox/{to}/messages/{id}`. Con la
///   persistencia en disco de Firebase activada, una escritura hecha
///   sin red se conserva (incluso si la app se cierra) y se envía al
///   reconectar.
/// - `incoming`: escucha `inbox/{deviceId}/messages`, en orden de
///   `createdAt`, y emite cada sobre. NO lo borra: el borrado ocurre
///   en [acknowledge], cuando `SyncService` terminó de procesarlo.
/// - `status`: refleja la conexión real (`.info/connected`).
///
/// El sobre viaja cifrado. Firebase nunca ve el contenido.
class FirebaseTransport implements SyncTransport {
  FirebaseTransport();

  // Una sola suscripción: bufferean hasta que SyncService escuche.
  // (Con broadcast, lo emitido durante initialize() se perdía.)
  final _incomingController = StreamController<SyncEnvelope>();
  final _statusController = StreamController<TransportStatus>();

  FirebaseDatabase? _db;
  String? _deviceId;
  bool _persistenceOn = false;

  StreamSubscription<DatabaseEvent>? _messagesSub;
  StreamSubscription<DatabaseEvent>? _connectionSub;

  /// ids ya emitidos y aún sin confirmar. Evita emitir dos veces el
  /// mismo sobre durante la sesión.
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

    // Si ya hay una app de Firebase inicializada (por ejemplo, porque
    // el transporte se reinicializa), la reusamos.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }

    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: config['databaseUrl'] as String?,
    );

    // Debe llamarse antes de cualquier otra operación sobre la
    // instancia. Si ya se usó, lanza: seguimos sin persistencia.
    try {
      db.setPersistenceEnabled(true);
      _persistenceOn = true;
    } catch (_) {
      _persistenceOn = false;
    }

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

    // Ordenado por createdAt para que lo acumulado offline llegue en
    // orden cronológico y no por el orden aleatorio de los uuid.
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
      // Basura en el buzón: no hay nada que procesar, se limpia.
      unawaited(ref.remove().catchError((Object _) {}));
      return;
    }

    final SyncEnvelope envelope;
    try {
      envelope = SyncEnvelope.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      // Sobre malformado: nunca se va a poder procesar. Se limpia
      // para no reintentarlo en cada arranque.
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

    // Sin await: con persistencia, remove() solo completa cuando el
    // servidor confirma, y sin red bloquearía la cola de proceso. El
    // borrado local se aplica al instante y el remoto se sube al
    // reconectar. Si falla, el sobre se reentrega y se deduplica.
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
      // Sin confirmación del servidor (casi seguro sin red). Con
      // persistencia en disco, Firebase conserva la escritura y la
      // sube al reconectar. Sin persistencia no hay garantía.
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
    // Sin await: en un StreamController de una sola suscripción, el
    // Future de close() no completa si nadie escuchó.
    unawaited(_incomingController.close());
    unawaited(_statusController.close());
    _emitted.clear();
    _db = null;
  }
}
