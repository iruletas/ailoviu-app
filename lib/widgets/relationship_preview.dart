import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/relationship_providers.dart';
import '../providers/settings_providers.dart';
import 'anniversary_card.dart';

/// Tarjeta hero de la relación. Muestra avatares, nombres, tipo,
/// y un badge con el tiempo transcurrido desde el inicio.
///
/// Se anima con fade + scale suave cuando cambian los datos.
/// Reutilizable en `relationship_screen.dart` y en Home.
class RelationshipPreview extends ConsumerWidget {
  const RelationshipPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rel = ref.watch(relationshipProvider);
    final seed = ref.watch(settingsProvider).seedColor;
    final scheme = Theme.of(context).colorScheme;

    final names = rel.visibleNames;
    final hasAnyData =
        names.any((n) => n.trim().isNotEmpty) || rel.startDate != null;

    final signature =
        '${names.join("|")}_${rel.type.name}_${rel.startDate?.toIso8601String()}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            Color.alphaBlend(
              scheme.tertiaryContainer.withValues(alpha: 0.45),
              scheme.primaryContainer,
            ),
          ],
        ),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
        child: _PreviewContent(
          key: ValueKey(signature),
          relationship: rel,
          seed: seed,
          hasAnyData: hasAnyData,
          names: names,
        ),
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  final AppRelationship relationship;
  final Color seed;
  final bool hasAnyData;
  final List<String> names;

  const _PreviewContent({
    super.key,
    required this.relationship,
    required this.seed,
    required this.hasAnyData,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!hasAnyData) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_outline_rounded,
              size: 48,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'Agrega sus nombres y la fecha de inicio para empezar',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      );
    }

    final displayNames = names
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < names.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
              _InitialAvatar(name: names[i], seed: seed),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Text(
          displayNames.isEmpty ? 'Sin nombres' : displayNames.join(' & '),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          relationship.type.label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
          ),
        ),
        if (relationship.startDate != null) ...[
          const SizedBox(height: 16),
          AnniversaryBadge(startDate: relationship.startDate!),
        ],
      ],
    );
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