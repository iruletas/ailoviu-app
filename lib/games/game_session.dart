import '../models/game_models.dart';
import 'game_definition.dart';

/// Wrapper de [GameSession] con la lógica de aplicar movimientos
/// usando un [GameDefinition].
class GameSessionController {
  GameSessionController({
    required GameDefinition definition,
    required GameSession session,
  })  : _definition = definition,
        _session = session;

  final GameDefinition _definition;
  GameSession _session;

  GameSession get session => _session;

  /// Aplica un movimiento local. Devuelve el [GameMove] aplicado.
  GameMove applyLocalMove({
    required String playerId,
    required String moveType,
    required Map<String, dynamic> data,
  }) {
    final move = GameMove(
      playerId: playerId,
      moveType: moveType,
      data: data,
      timestamp: DateTime.now(),
    );
    _session = _definition.applyMove(_session, move);
    return move;
  }

  /// Aplica un movimiento remoto. Si llega con [GameMove.timestamp]
  /// menor al último aplicado, lo descarta (para evitar retrocesos
  /// en resync).
  bool applyRemoteMove(GameMove move) {
    final lastMoveAt = _session.updatedAt;
    if (move.timestamp.isBefore(lastMoveAt)) {
      return false;
    }
    _session = _definition.applyMove(_session, move);
    return true;
  }

  /// Reemplaza el estado completo (para resync).
  void replaceState(GameSession session) {
    if (session.version >= _session.version) {
      _session = session;
    }
  }

  bool get isFinished => _definition.isFinished(_session);

  Map<String, int> get score => _definition.score(_session);
}