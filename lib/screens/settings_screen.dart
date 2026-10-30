import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_settings_providers.dart';
import '../providers/map_key_provider.dart';
import '../providers/settings_providers.dart';
import '../widgets/about_footer_card.dart';
import '../widgets/relationship_summary_card.dart';
import '../widgets/settings_components.dart';
import '../widgets/tonal_back_button.dart';
import 'about_screen.dart';
import 'appearance_screen.dart';
import 'infrastructure_screen.dart';
import 'relationship_screen.dart';
import 'security_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
              'Ajustes',
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
                const SectionLabel('Preferencias'),
                const SizedBox(height: 8),
                SettingsGroupCard(
                  child: Column(
                    children: [
                      SettingsTileExpressive(
                        leading: TonalIconBubble(
                          icon: Icons.palette_outlined,
                          background: scheme.primaryContainer,
                          foreground: scheme.onPrimaryContainer,
                        ),
                        title: 'Tema y color',
                        subtitle: ThemeBadges(settings: settings),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _openOrganic(context, const AppearanceScreen());
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 70,
                        endIndent: 16,
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                      SettingsTileExpressive(
                        leading: const _SecurityLeading(),
                        title: 'Seguridad',
                        subtitle: const _SecuritySubtitle(),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _openOrganic(context, const SecurityScreen());
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 70,
                        endIndent: 16,
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                      SettingsTileExpressive(
                        leading: const _InfrastructureLeading(),
                        title: 'Conexiones',
                        subtitle: const _InfrastructureSubtitle(),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _openOrganic(context, const InfrastructureScreen());
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionLabel('Relación'),
                const SizedBox(height: 8),
                RelationshipSummaryCard(
                  variant: RelationshipCardVariant.hero,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _openOrganic(context, const RelationshipScreen());
                  },
                ),
                const SizedBox(height: 24),
                AboutFooterCard(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _openOrganic(context, const AboutScreen());
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static void _openOrganic(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

// ── Ícono de Seguridad ───────────────────────────────────────────────────
class _SecurityLeading extends ConsumerWidget {
  const _SecurityLeading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authSettingsProvider);
    final enabled = auth.appLockEnabled;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: scheme.secondary.withValues(alpha: 0.28),
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
          enabled ? Icons.lock_rounded : Icons.lock_outline_rounded,
          key: ValueKey(enabled),
          size: 20,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _SecuritySubtitle extends ConsumerWidget {
  const _SecuritySubtitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authSettingsProvider);

    Widget chip;
    if (!auth.loaded) {
      chip = MiniChip(
        key: const ValueKey('loading'),
        label: 'Cargando…',
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurfaceVariant,
      );
    } else if (!auth.appLockEnabled) {
      chip = MiniChip(
        key: const ValueKey('off'),
        label: 'Desactivado',
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurfaceVariant,
      );
    } else {
      final label = auth.appLockTimeout == null
          ? 'Bloqueo activo'
          : 'Bloqueo ${_timeoutLabel(auth.appLockTimeout!)}';
      chip = Row(
        key: const ValueKey('on'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          MiniChip(
            label: label,
            background: scheme.tertiaryContainer,
            foreground: scheme.onTertiaryContainer,
            bold: true,
          ),
        ],
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

  static String _timeoutLabel(Duration d) {
    if (d == Duration.zero) return 'inmediato';
    final m = d.inMinutes;
    if (m == 1) return '1 min';
    return '$m min';
  }
}

// ── Ícono de Conexiones ──────────────────────────────────────────────────
class _InfrastructureLeading extends ConsumerWidget {
  const _InfrastructureLeading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // En el futuro, habrá otros providers aquí (ej. Firebase).
    final hasCartoKey = ref.watch(cartoKeyProvider).isNotEmpty;
    final hasActiveService = hasCartoKey;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasActiveService
            ? scheme.tertiaryContainer
            : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
        boxShadow: hasActiveService
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
          hasActiveService ? Icons.hub_rounded : Icons.hub_outlined,
          key: ValueKey(hasActiveService),
          size: 20,
          color: hasActiveService
              ? scheme.onTertiaryContainer
              : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

// ── Subtítulo de Conexiones ──────────────────────────────────────────────
class _InfrastructureSubtitle extends ConsumerWidget {
  const _InfrastructureSubtitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasCartoKey = ref.watch(cartoKeyProvider).isNotEmpty;

    Widget chip;
    if (hasCartoKey) {
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
            label: 'CARTO activo',
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