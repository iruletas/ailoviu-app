import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Botón de retroceso tonal M3E. Contenedor `surfaceContainerHigh`
/// con háptica ligera al toque.
///
/// Reutilizable en cualquier pantalla push (Appearance, Relationship,
/// About, futuras). Sustituye el `IconButton` plano del `AppBar`.
class TonalBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const TonalBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Volver',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      onPressed: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      icon: const Icon(Icons.arrow_back_rounded),
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainerHigh,
        foregroundColor: scheme.onSurface,
      ),
      tooltip: tooltip,
    );
  }
}