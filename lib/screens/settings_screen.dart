import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_providers.dart';
import '../widgets/about_footer_card.dart';
import '../widgets/relationship_summary_card.dart';
import '../widgets/settings_components.dart';
import '../widgets/tonal_back_button.dart';
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
                    onTap: () => _openOrganic(
                      context,
                      const AppearanceScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
                AboutFooterCard(
                  onTap: () => _openOrganic(context, const AboutScreen()),
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