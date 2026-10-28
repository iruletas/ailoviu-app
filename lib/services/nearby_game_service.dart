import 'dart:async';

/// Servicio de conexión para juegos en persona.
///
/// Usa `nearby_connections` (Wi-Fi Direct + Bluetooth) para conectar
/// dos dispositivos sin nube, sin internet, sin Firebase.
///
/// La sesión es efímera: no se persiste. Si los dispositivos se
/// desconectan, la partida se pierde (o se guarda localmente para
/// continuar después, según cada juego).
class NearbyGameService {
  NearbyGameService();

  final _messagesController =
      StreamController<NearbyMessage>.broadcast();
  final _statusController =
      StreamController<NearbyStatus>.broadcast();

  NearbyStatus _status = NearbyStatus.idle;

  Stream<NearbyMessage> get messages => _messagesController.stream;
  Stream<NearbyStatus> get status => _statusController.stream;
  NearbyStatus get currentStatus => _status;

  /// Inicia el descubrimiento de dispositivos cercanos.
  ///
  /// TODO: implementar con `nearby_connections`.
  /// Requiere permisos de Bluetooth y Wi-Fi (ya declarados en el
  /// manifest). Requiere aceptar el permiso en runtime.
  Future<void> startDiscovery() async {
    _setStatus(NearbyStatus.discovering);
    // TODO: `NearbyConnections.startDiscovery(...)`
  }

  /// Se conecta a un dispositivo por su endpointId.
  ///
  /// TODO: implementar con `nearby_connections`.
  Future<void> connect(String endpointId) async {
    _setStatus(NearbyStatus.connecting);
    // TODO: `NearbyConnections.requestConnection(...)`
  }

  /// Envía un mensaje al otro dispositivo.
  ///
  /// TODO: implementar con `nearby_connections`.
  Future<void> send(
    String endpointId,
    Map<String, dynamic> message,
  ) async {
    // TODO: `NearbyConnections.sendPayload(...)`
  }

  /// Cierra la conexión.
  Future<void> dispose() async {
    await _messagesController.close();
    await _statusController.close();
  }

  void _setStatus(NearbyStatus status) {
    if (_status == status) return;
    _status = status;
    _statusController.add(status);
  }
}

class NearbyMessage {
  final String fromEndpointId;
  final Map<String, dynamic> data;

  const NearbyMessage({
    required this.fromEndpointId,
    required this.data,
  });
}

enum NearbyStatus { idle, discovering, connecting, connected, error }