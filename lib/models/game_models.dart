import 'package:flutter/foundation.dart';

/// Modo de un juego.
///
/// Determina qué infraestructura usa:
/// - [async] y [realtime]: `SyncService` (Firebase).
/// - [singleScreen]: `LocalGameService` (Flutter puro, sin red).
/// - [nearby]: `NearbyGameService` (Nearby Connections, sin nube).
enum GameMode { async, realtime, singleScreen, nearby }

/// Un movimiento de juego.
@immutable
class GameMove {
  final String playerId;

  /// "answer", "spin", "pick", "tap", "draw", etc. Cada juego define
  /// sus tipos.
  final String moveType;

  /// Datos del movimiento. Serializable a JSON.
  final Map<String, dynamic> data;

  final DateTime timestamp;

  const GameMove({
    required this.playerId,
    required this.moveType,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'moveType': moveType,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  static GameMove fromJson(Map<String, dynamic> json) => GameMove(
        playerId: json['playerId'] as String,
        moveType: json['moveType'] as String,
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? {},
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Estado de una partida.
///
/// [state] es opaco para la infraestructura: cada juego lo define. La
/// infraestructura solo lo cifra, lo manda y lo entrega.
@immutable
class GameSession {
  final String id;
  final String gameId;
  final List<String> playerIds;
  final Map<String, dynamic> state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool finished;

  /// Se incrementa con cada movimiento. Sirve para resolver
  /// conflictos sin "last-write-wins".
  final int version;

  const GameSession({
    required this.id,
    required this.gameId,
    required this.playerIds,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.finished = false,
    this.version = 0,
  });

  GameSession copyWith({
    Map<String, dynamic>? state,
    DateTime? updatedAt,
    bool? finished,
    int? version,
  }) {
    return GameSession(
      id: id,
      gameId: gameId,
      playerIds: playerIds,
      state: state ?? this.state,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      finished: finished ?? this.finished,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'gameId': gameId,
        'playerIds': playerIds,
        'state': state,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'finished': finished,
        'version': version,
      };

  static GameSession fromJson(Map<String, dynamic> json) => GameSession(
        id: json['id'] as String,
        gameId: json['gameId'] as String,
        playerIds:
            (json['playerIds'] as List).cast<String>(),
        state: (json['state'] as Map?)?.cast<String, dynamic>() ?? {},
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        finished: json['finished'] as bool? ?? false,
        version: json['version'] as int? ?? 0,
      );
}