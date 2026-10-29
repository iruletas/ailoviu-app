import '../models/sync_models.dart';

/// Interfaz de un transporte de sobres.
///
/// `SyncService` la usa para enviar y recibir sobres cifrados.
/// No sabe si es Firebase, Cloudflare, o lo que sea. Solo ve
/// [SyncEnvelope] cifrados.
///
/// Contrato de entrega (at-least-once):
/// - [incoming] y [status] son streams de UNA sola suscripción y
///   bufferean lo que ocurra antes de que alguien escuche. Los usa
///   solamente `SyncService`.
/// - El transporte NUNCA borra un sobre por su cuenta. El buzón se
///   limpia únicamente con [acknowledge], que el receptor llama
///   después de procesar el sobre. Si la app muere antes, el sobre
///   sigue en el buzón y se reentrega al siguiente arranque.
/// - Por eso el receptor debe deduplicar por `SyncEnvelope.id`.
abstract class SyncTransport {
  /// Inicializa el transporte con la config dada.
  Future<void> initialize(Map<String, dynamic> config);

  /// Envía un sobre cifrado.
  Future<TransportResult> send(SyncEnvelope envelope);

  /// Escucha sobres entrantes. El sobre llega tal cual (cifrado).
  Stream<SyncEnvelope> get incoming;

  /// Confirma que el sobre [envelopeId] ya se procesó (o que no tiene
  /// arreglo y se descarta) y que puede borrarse del buzón.
  Future<void> acknowledge(String envelopeId);

  /// Estado del transporte.
  Stream<TransportStatus> get status;

  /// Cierra el transporte.
  Future<void> dispose();
}
