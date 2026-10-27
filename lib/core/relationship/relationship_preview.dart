import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_providers.dart';
import 'relationship_providers.dart';

class RelationshipPreview extends ConsumerWidget {
  const RelationshipPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rel = ref.watch(relationshipProvider);
    final seed = ref.watch(settingsProvider).seedColor;
    final theme = Theme.of(context);

    final names = rel.visibleNames;
    final hasAnyName = names.any((n) => n.trim().isNotEmpty);
    final start = rel.startDate;

    if (!hasAnyName && start == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Agrega sus nombres y la fecha de inicio para empezar',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final days = start == null
        ? null
        : math.max(0, DateTime.now().difference(start).inDays);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < names.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.favorite,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
              _InitialAvatar(name: names[i], seed: seed),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _displayNames(names),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          rel.type.label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (start != null) ...[
          const SizedBox(height: 4),
          Text(
            _startLabel(start, days!),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  String _displayNames(List<String> names) {
    final filled = names.map((n) => n.trim()).where((n) => n.isNotEmpty);
    if (filled.isEmpty) return 'Sin nombres';
    return filled.join(' & ');
  }

  String _startLabel(DateTime start, int days) {
    final d = start.day.toString().padLeft(2, '0');
    final m = start.month.toString().padLeft(2, '0');
    final y = start.year;
    final dayWord = days == 1 ? 'día' : 'días';
    return 'Juntos desde el $d/$m/$y · $days $dayWord';
  }
}

class _InitialAvatar extends StatelessWidget {
  final String name;
  final Color seed;

  const _InitialAvatar({required this.name, required this.seed});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? null : trimmed[0].toUpperCase();

    return Semantics(
      label: trimmed.isEmpty ? 'Avatar sin nombre' : 'Avatar de $trimmed',
      child: CircleAvatar(
        radius: 32,
        backgroundColor: initial == null
            ? scheme.surfaceContainerHighest
            : scheme.primary,
        child: initial == null
            ? Icon(
                Icons.person_outline,
                color: scheme.onSurfaceVariant,
              )
            : Text(
                initial,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimary,
                ),
              ),
      ),
    );
  }
}