import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_info_providers.dart';
import '../widgets/about_hero_card.dart';
import '../widgets/settings_components.dart';
import '../widgets/tonal_back_button.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

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
              'Acerca de',
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
                // ── Hero ────────────────────────────────────────────
                const AboutHeroCard(),
                const SizedBox(height: 24),

                // ── Propósito ───────────────────────────────────────
                const _PurposeCard(),
                const SizedBox(height: 16),

                // ── Licencias ───────────────────────────────────────
                _LicensesCard(
                  onTap: () => _openLicenses(context, ref),
                ),
                const SizedBox(height: 16),

                // ── Acciones rápidas ────────────────────────────────
                _ActionChipsRow(
                  onRate: () => _notYet(context, 'Calificar la app'),
                  onWebsite: () => _notYet(context, 'Sitio web'),
                  onShare: () => _notYet(context, 'Compartir'),
                ),
                const SizedBox(height: 32),

                // ── Footer copyright ────────────────────────────────
                _CopyrightFooter(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _notYet(BuildContext context, String feature) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — próximamente'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openLicenses(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    final version = ref.read(appVersionProvider).valueOrNull ?? '';
    showLicensePage(
      context: context,
      applicationName: 'Ailoviu',
      applicationVersion: version.isEmpty ? null : 'v$version',
      applicationIcon: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.favorite_rounded,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 28,
          ),
        ),
      ),
    );
  }
}

// ── Propósito ────────────────────────────────────────────────────────────
class _PurposeCard extends StatelessWidget {
  const _PurposeCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TonalIconBubble(
            icon: Icons.auto_awesome_rounded,
            background: scheme.secondaryContainer,
            foreground: scheme.onSecondaryContainer,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            'Ailoviu está diseñada para celebrar el amor, crear recuerdos '
            'juntos y mantener viva la conexión cada día.',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.5,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 14,
                color: scheme.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Hecho con amor para ti y tu persona favorita',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Licencias ────────────────────────────────────────────────────────────
class _LicensesCard extends StatefulWidget {
  final VoidCallback onTap;
  const _LicensesCard({required this.onTap});

  @override
  State<_LicensesCard> createState() => _LicensesCardState();
}

class _LicensesCardState extends State<_LicensesCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              TonalIconBubble(
                icon: Icons.code_rounded,
                background: scheme.secondaryContainer,
                foreground: scheme.onSecondaryContainer,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Licencias de código abierto',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Componentes, dependencias y créditos de software',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Acciones rápidas ─────────────────────────────────────────────────────
class _ActionChipsRow extends StatelessWidget {
  final VoidCallback onRate;
  final VoidCallback onWebsite;
  final VoidCallback onShare;

  const _ActionChipsRow({
    required this.onRate,
    required this.onWebsite,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionChip(
            icon: Icons.star_outline_rounded,
            label: 'Calificar',
            onTap: onRate,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionChip(
            icon: Icons.public_rounded,
            label: 'Sitio web',
            onTap: onWebsite,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionChip(
            icon: Icons.share_outlined,
            label: 'Compartir',
            onTap: onShare,
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: scheme.onTertiaryContainer,
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Copyright footer ─────────────────────────────────────────────────────
class _CopyrightFooter extends StatelessWidget {
  const _CopyrightFooter();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final year = DateTime.now().year;

    return Column(
      children: [
        Text(
          '© $year Ailoviu',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Todos los derechos reservados',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}