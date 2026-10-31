import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/invite_service.dart';

class QrInviteCard extends StatelessWidget {
  final GroupInvitePayload invite;
  const QrInviteCard({super.key, required this.invite});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: scheme.surfaceContainerLow,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Escanea para unirte',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () async {
                  await HapticFeedback.lightImpact();
                  Clipboard.setData(
                    ClipboardData(text: invite.encodeForQr()),
                  );
                  if (context.mounted) {
                    _showCopiedToast(context);
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                ),
                tooltip: 'Copiar como texto',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
              ),
              child: QrImageView(
                data: invite.encodeForQr(),
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_rounded,
                    size: 14,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Caduca a las ${_formatTime(invite.expiresAt)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showCopiedToast(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'QR copiado al portapapeles',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}