import 'package:flutter/material.dart';

import '../models/game_models.dart';

/// Contrato de un juego.
///
/// Cada juego (ruleta, preguntas, charadas, etc.) implementa esto.
/// La infraestructura no sabe de juegos concretos: solo llama a
/// estos métodos.
abstract class GameDefinition {
  /// id único del juego (ej. "truth_or_dare").
  String get id;

  /// Título visible.
  String get title;

  /// Descripción corta.
  String get description;

  /// Ícono para la UI.
  IconData get icon;

  /// Modo del juego.
  GameMode get mode;

  /// Crea una sesión nueva con los jugadores dados.
  GameSession createSession({required List<String> playerIds});

  /// Aplica un movimiento. Devuelve la sesión actualizada.
  GameSession applyMove(GameSession session, GameMove move);

  /// `true` si la partida terminó.
  bool isFinished(GameSession session);

  /// Puntaje final (vacío si el juego no tiene puntaje).
  Map<String, int> score(GameSession session);
}