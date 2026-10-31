import 'package:flutter/material.dart';

import 'linking_pill_button.dart';

class EmptyGroupCard extends StatelessWidget {
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const EmptyGroupCard({
    super.key,
    required this.busy,
    required this.onCreate,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              scheme.primaryContainer.withValues(alpha: 0.85),
              scheme.surfaceContainerLow,
            ),
            scheme.surfaceContainerLow,
          ],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.groups_rounded,
              size: 26,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Vincular dispositivos',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'El primero crea el grupo. Los demás se unen escaneando el QR.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          LinkingPillButton(
            label: 'Crear grupo',
            icon: Icons.add_rounded,
            busy: busy,
            filled: true,
            background: scheme.primary,
            foreground: scheme.onPrimary,
            onTap: onCreate,
          ),
          const SizedBox(height: 10),
          LinkingPillButton(
            label: 'Unirme a un grupo',
            icon: Icons.qr_code_scanner_rounded,
            busy: false,
            filled: false,
            background: scheme.secondaryContainer,
            foreground: scheme.onSecondaryContainer,
            onTap: onJoin,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Si es tu primera vez, configura Firebase antes en '
                    '"Conexiones → Firebase".',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}