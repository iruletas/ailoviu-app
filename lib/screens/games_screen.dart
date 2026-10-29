import 'package:flutter/material.dart';

/// Pestaña "Juegos".
///
/// Solo videojuegos interactivos: ruletas, preguntas, charadas.
///
/// Placeholder hasta que exista la feature real. La primera versión
/// probablemente sea un solo juego (Ruleta de decisiones) jugable en
/// pantalla compartida.
class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.sports_esports_rounded,
              size: 32,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Juegos',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Próximamente',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}