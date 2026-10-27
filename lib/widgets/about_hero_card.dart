import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_info_providers.dart';
import 'settings_components.dart';
import 'shape_selector_card.dart';

/// Tarjeta hero de "Acerca de Ailoviu".
///
/// Corazón con heartbeat animado, nombre grande, chip de versión
/// dinámico y easter egg háptico (doble vibración al tocar el corazón).
class AboutHeroCard extends ConsumerStatefulWidget {
  const AboutHeroCard({super.key});

  @override
  ConsumerState<AboutHeroCard> createState() => _AboutHeroCardState();
}

class _AboutHeroCardState extends ConsumerState<AboutHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartbeatController;
  late final Animation<double> _heartbeatScale;

  @override
  void initState() {
    super.initState();
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _heartbeatScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _heartbeatController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    super.dispose();
  }

  Future<void> _doubleHaptic() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final versionAsync = ref.watch(appVersionProvider);
    final version = versionAsync.when(
      data: (v) => v,
      loading: () => '...',
      error: (_, __) => '?',
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            Color.alphaBlend(
              scheme.surfaceContainerLow.withValues(alpha: 0.6),
              scheme.primaryContainer,
            ),
          ],
        ),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _doubleHaptic,
            onLongPress: _doubleHaptic,
            child: ScaleTransition(
              scale: _heartbeatScale,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(22),
                  color: scheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: ShapeIcon(
                    shape: M3EShape.heart,
                    color: scheme.onPrimary,
                    filled: true,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Ailoviu',
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          MiniChip(
            label: 'v$version',
            background: scheme.tertiaryContainer,
            foreground: scheme.onTertiaryContainer,
            bold: true,
          ),
        ],
      ),
    );
  }
}