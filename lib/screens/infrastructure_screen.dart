import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/map_key_provider.dart';
import '../widgets/carto_key_dialog.dart';
import '../widgets/settings_components.dart';
import '../widgets/tonal_back_button.dart';

/// Pantalla de infraestructura y conexiones.
///
/// Aquí vivirán las configuraciones de servicios externos:
/// - Mapa (API Key de CARTO).
/// - Firebase (en el futuro).
class InfrastructureScreen extends ConsumerWidget {
  const InfrastructureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    
    final hasKey = ref.watch(cartoKeyProvider).isNotEmpty;
    // En el futuro, cuando Firebase esté implementado, esta variable
    // también leerá su provider para saber si está configurado.
    final activeServices = hasKey ? 1 : 0;
    final totalServices = 1; // Cambiará a 2 cuando Firebase exista.

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar.large(
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: TonalBackButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            title: Text(
              'Conexiones',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── 1. Hero de Estado Global ───────────────────────────
                _NetworkStatusHero(
                  active: activeServices,
                  total: totalServices,
                ),
                const SizedBox(height: 24),

                // ── 2. Isla 1: Geolocalización ─────────────────────────
                const SectionLabel('Geolocalización'),
                const SizedBox(height: 8),
                SettingsGroupCard(
                  child: SettingsTileExpressive(
                    leading: const _MapLeading(),
                    title: 'Mapa',
                    subtitle: const _MapSubtitle(),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasKey)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: scheme.tertiary,
                              size: 18,
                            ),
                          ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      CartoKeyDialog.show(context);
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // ── 3. Isla 2: Sincronización y Respaldo ───────────────
                const SectionLabel('Sincronización y respaldo'),
                const SizedBox(height: 8),
                SettingsGroupCard(
                  child: AnimatedOpacity(
                    opacity: 0.7,
                    duration: const Duration(milliseconds: 260),
                    child: SettingsTileExpressive(
                      leading: TonalIconBubble(
                        icon: Icons.local_fire_department_outlined,
                        background: scheme.surfaceContainerHighest,
                        foreground: scheme.onSurfaceVariant,
                      ),
                      title: 'Firebase',
                      subtitle: const Text('Base de datos y sync E2EE'),
                      trailing: MiniChip(
                        label: 'Próximamente',
                        background: scheme.surfaceContainerHighest,
                        foreground: scheme.onSurfaceVariant,
                      ),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showFirebasePreviewSheet(context);
                      },
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom Sheet informativo para Firebase (reemplaza el SnackBar).
  void _showFirebasePreviewSheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.cloud_sync_rounded,
                  size: 32,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Sincronización E2EE',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pronto podrás conectar Firebase para sincronización en '
                'tiempo real y respaldo automático en la nube.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                child: const Text('¡Entendido!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// COMPONENTES DE ESTADO
// ═══════════════════════════════════════════════════════════════════════

/// Hero Card que muestra el estado global de los servicios.
class _NetworkStatusHero extends StatelessWidget {
  final int active;
  final int total;

  const _NetworkStatusHero({
    required this.active,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final allActive = active == total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              scheme.primaryContainer.withValues(alpha: 0.15),
              scheme.surfaceContainerLow,
            ),
            Color.alphaBlend(
              scheme.tertiaryContainer.withValues(alpha: 0.10),
              scheme.surfaceContainerLow,
            ),
          ],
        ),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.hub_rounded,
              size: 24,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Infraestructura y Nube',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (allActive) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      '$active de $total ${total == 1 ? "servicio activo" : "servicios activos"}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: allActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// COMPONENTES REACTIVOS PARA EL MAPA
// ═══════════════════════════════════════════════════════════════════════

class _MapLeading extends ConsumerWidget {
  const _MapLeading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasKey = ref.watch(cartoKeyProvider).isNotEmpty;

    final bg = hasKey ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final fg = hasKey ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;
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

class _MapSubtitle extends ConsumerWidget {
  const _MapSubtitle();

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