import 'package:flutter/material.dart';

/// Pestaña "Días".
///
/// Vista de tiempo de la relación: días especiales, cumpleaños,
/// recordatorios, menstruación, citas planeadas.
///
/// Placeholder hasta que exista la feature real. El contenido completo
/// (lista cronológica + calendario + CRUD) es otra sesión.
class DaysScreen extends StatelessWidget {
  const DaysScreen({super.key});

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
              Icons.calendar_month_rounded,
              size: 32,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Días',
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