import '../games/game_definition.dart';
import '../games/game_session.dart';
import '../models/game_models.dart';

/// Servicio de juegos de una pantalla.
///
/// No usa red. No usa Firebase. No usa Nearby. Solo Flutter puro.
/// El estado vive en memoria y se pierde al cerrar la app (o se
/// guarda localmente si el juego lo decide).
class LocalGameService {
  LocalGameService();

  GameSessionController? _current;

  GameSessionController? get current => _current;

  /// Inicia una sesión local para el juego dado.
  GameSessionController start(
    GameDefinition definition, {
    required List<String> playerIds,
  }) {
    final session = definition.createSession(playerIds: playerIds);
    _current = GameSessionController(
      definition: definition,
      session: session,
    );
    return _current!;
  }

  /// Aplica un movimiento local.
  GameMove? applyMove({
    required String playerId,
    required String moveType,
    required Map<String, dynamic> data,
  }) {
    final controller = _current;
    if (controller == null) return null;
    return controller.applyLocalMove(
      playerId: playerId,
      moveType: moveType,
      data: data,
    );
  }

  /// Termina la sesión actual.
  void end() {
    _current = null;
  }
}