import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_providers.dart';
import '../widgets/about_footer_card.dart';
import '../widgets/relationship_summary_card.dart';
import '../widgets/settings_components.dart';
import 'about_screen.dart';
import 'appearance_screen.dart';
import 'relationship_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Ajustes',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Apariencia ─────────────────────────────────────────────
          const SectionLabel('Apariencia'),
          const SizedBox(height: 8),
          SettingsGroupCard(
            child: SettingsTileExpressive(
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
              onTap: () => _openOrganic(context, const AppearanceScreen()),
            ),
          ),

          const SizedBox(height: 24),

          // ── Relación ───────────────────────────────────────────────
          const SectionLabel('Relación'),
          const SizedBox(height: 8),
          RelationshipSummaryCard(
            variant: RelationshipCardVariant.hero,
            onTap: () => _openOrganic(
              context,
              const RelationshipScreen(),
            ),
          ),

          const SizedBox(height: 24),

          // ── Acerca de ──────────────────────────────────────────────
          AboutFooterCard(
            onTap: () => _openOrganic(context, const AboutScreen()),
          ),
        ],
      ),
    );
  }

  /// Transición orgánica casera: fade + scale. Sin paquetes extra.
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