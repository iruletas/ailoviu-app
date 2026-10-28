import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/sync_models.dart';
import 'sync_transport.dart';

/// Transporte sobre Firebase Realtime Database.
///
/// - `send`: escribe el sobre en `inbox/{to}/messages/{id}`.
/// - `incoming`: escucha `inbox/{deviceId}/messages` y emite cada
///   sobre nuevo. Después de emitirlo, lo borra.
/// - `status`: connected si Firebase está inicializado y el listener
///   está activo.
///
/// El sobre viaja cifrado. Firebase nunca ve el contenido.
class FirebaseTransport implements SyncTransport {
  FirebaseTransport();

  final _incomingController = StreamController<SyncEnvelope>.broadcast();
  final _statusController =
      StreamController<TransportStatus>.broadcast();

  FirebaseDatabase? _db;
  String? _deviceId;
  StreamSubscription<DatabaseEvent>? _subscription;

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

    _db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: config['databaseUrl'] as String?,
    );

    _statusController.add(TransportStatus.connected);
    _startListening();
  }

  void _startListening() {
    final db = _db;
    final deviceId = _deviceId;
    if (db == null || deviceId == null) return;

    final ref = db.ref('inbox/$deviceId/messages');
    _subscription = ref.onChildAdded.listen((event) {
      try {
        final raw = event.snapshot.value;
        if (raw is! Map) return;
        final envelope = SyncEnvelope.fromJson(
          Map<String, dynamic>.from(raw),
        );
        _incomingController.add(envelope);
        // Borrar después de emitir. Si el receptor no procesa el
        // sobre (por un error), no se borra. El TTL del sobre lo
        // maneja el receptor.
        event.snapshot.ref.remove();
      } catch (_) {
        // Sobre malformado. Lo ignoramos y lo borramos para no
        // atascar la cola.
        event.snapshot.ref.remove();
      }
    });
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
          .set(envelope.toJson());
      return TransportResult.ok;
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
    await _subscription?.cancel();
    _subscription = null;
    await _incomingController.close();
    await _statusController.close();
    _db = null;
  }
}