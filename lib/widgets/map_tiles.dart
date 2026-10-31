import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/map_key_provider.dart';
import 'settings_components.dart';

class MapLeading extends ConsumerWidget {
  const MapLeading({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasKey = ref.watch(cartoKeyProvider).isNotEmpty;

    final bg = hasKey ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final fg =
        hasKey ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;
    final icon = hasKey ? Icons.map_rounded : Icons.map_outlined;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: hasKey
            ? [
                BoxShadow(
                  color: scheme.tertiary.withValues(alpha: 0.28),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          icon,
          key: ValueKey(hasKey),
          size: 20,
          color: fg,
        ),
      ),
    );
  }
}

class MapSubtitle extends ConsumerWidget {
  const MapSubtitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasKey = ref.watch(cartoKeyProvider).isNotEmpty;

    Widget chip;
    if (hasKey) {
      chip = Row(
        key: const ValueKey('carto'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: scheme.tertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          MiniChip(
            label: 'CARTO Limpio',
            background: scheme.tertiaryContainer,
            foreground: scheme.onTertiaryContainer,
            bold: true,
          ),
        ],
      );
    } else {
      chip = MiniChip(
        key: const ValueKey('osm'),
        label: 'OpenStreetMap',
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurfaceVariant,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
      child: chip,
    );
  }
}