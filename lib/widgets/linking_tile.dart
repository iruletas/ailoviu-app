import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_providers.dart';
import '../screens/linking_screen.dart';
import 'settings_components.dart';

class LinkingTile extends ConsumerWidget {
  const LinkingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final groupAsync = ref.watch(groupSnapshotProvider);
    final group = groupAsync.valueOrNull;

    final groupId = group?.groupId;
    final approvedCount = group == null
        ? 0
        : group.members.values.where((m) => m.approved).length;
    final isLinked = groupId != null && approvedCount > 1;

    final statusText = groupId == null
        ? 'Sin configurar'
        : approvedCount == 1
            ? '1 miembro'
            : '$approvedCount miembros';

    final icon = isLinked ? Icons.link_rounded : Icons.link_off_rounded;
    final bubbleBg =
        isLinked ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final bubbleFg = isLinked
        ? scheme.onTertiaryContainer
        : scheme.onSecondaryContainer;

    return SettingsGroupCard(
      child: SettingsTileExpressive(
        leading: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bubbleBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isLinked
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
              key: ValueKey(isLinked),
              size: 20,
              color: bubbleFg,
            ),
          ),
        ),
        title: 'Vinculación',
        subtitle: isLinked
            ? Row(
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
                    label: statusText,
                    background: scheme.tertiaryContainer,
                    foreground: scheme.onTertiaryContainer,
                    bold: true,
                  ),
                ],
              )
            : MiniChip(
                label: statusText,
                background: scheme.surfaceContainerHighest,
                foreground: scheme.onSurfaceVariant,
              ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: scheme.onSurfaceVariant,
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 320),
              reverseTransitionDuration: const Duration(milliseconds: 240),
              pageBuilder: (_, __, ___) => const LinkingScreen(),
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
        },
      ),
    );
  }
}