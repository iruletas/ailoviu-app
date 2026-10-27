import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tarjeta de acción destructiva con tono de error suave.
///
/// Se usa en `relationship_screen.dart` para "Restablecer datos de la
/// relación". Reutilizable para "Cerrar cuenta", "Borrar todo", etc.
/// cuando llegue backend.
class DangerActionCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const DangerActionCard({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.delete_outline_rounded,
  });

  @override
  State<DangerActionCard> createState() => _DangerActionCardState();
}

class _DangerActionCardState extends State<DangerActionCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap();
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
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.error.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.error,
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: scheme.onError,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: scheme.onErrorContainer.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo confirmatorio M3E: ícono grande de advertencia, título,
/// descripción, y acciones Cancelar / Confirmar (FilledButton error).
///
/// Devuelve `true` si el usuario confirma, `false` o `null` si cancela.
/// Se abre con `showDialog<bool>(...)`.
class ConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;

  const ConfirmDeleteDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelLabel = 'Cancelar',
    this.confirmLabel = 'Eliminar',
  });

  /// Helper estático para abrir el diálogo y esperar el resultado.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String cancelLabel = 'Cancelar',
    String confirmLabel = 'Eliminar',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDeleteDialog(
        title: title,
        message: message,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(36),
      ),
      backgroundColor: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.errorContainer,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 32,
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context, false);
                    },
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context, true);
                    },
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}