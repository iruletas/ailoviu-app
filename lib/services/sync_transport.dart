import '../models/sync_models.dart';

/// Interfaz de un transporte de sobres.
///
/// `SyncService` la usa para enviar y recibir sobres cifrados.
/// No sabe si es Firebase, Cloudflare, o lo que sea. Solo ve
/// [SyncEnvelope] cifrados.
abstract class SyncTransport {
  /// Inicializa el transporte con la config dada.
  Future<void> initialize(Map<String, dynamic> config);

  /// Envía un sobre cifrado.
  Future<TransportResult> send(SyncEnvelope envelope);

  /// Escucha sobres entrantes. El sobre llega tal cual (cifrado).
  Stream<SyncEnvelope> get incoming;

  /// Estado del transporte.
  Stream<TransportStatus> get status;

  /// Cierra el transporte.
  Future<void> dispose();
}