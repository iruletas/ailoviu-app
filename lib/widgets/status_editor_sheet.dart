import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_providers.dart';

/// Bottom sheet para editar el estado propio.
class StatusEditorSheet extends ConsumerStatefulWidget {
  const StatusEditorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const StatusEditorSheet(),
    );
  }

  @override
  ConsumerState<StatusEditorSheet> createState() => _StatusEditorSheetState();
}

class _StatusEditorSheetState extends ConsumerState<StatusEditorSheet> {
  late final TextEditingController _controller;
  
  static const int _maxLength = 60;

  @override
  void initState() {
    super.initState();
    final current = ref.read(myStatusProvider);
    // Como ya no hay emojis por separado, si por retrocompatibilidad
    // hay un emoji guardado, lo unimos al texto para que el usuario lo edite.
    final initialText = current != null 
        ? current.displayText 
        : '';
    _controller = TextEditingController(text: initialText);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      await ref.read(myStatusProvider.notifier).clear();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final deviceId = ref.read(myDeviceIdProvider).valueOrNull ?? '';
    if (deviceId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Espera a que la app termine de inicializar'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    await ref.read(myStatusProvider.notifier).setStatus(
          text: text,
          emoji: null, // Ya no usamos emoji por separado
          authorDeviceId: deviceId,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    await ref.read(myStatusProvider.notifier).clear();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final length = _controller.text.length;
    final currentStatus = ref.watch(myStatusProvider);
    final hasSavedStatus = currentStatus != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(36),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Título
            Row(
              children: [
                Expanded(
                  child: Text(
                    '¿Cómo te sientes ahora?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                // Botón de borrar explícito si ya hay estado guardado
                if (hasSavedStatus)
                  IconButton(
                    onPressed: _clear,
                    icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                    tooltip: 'Quitar estado',
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Badge de expiración
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 12,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Expira automáticamente en 24h',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Campo de texto
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _controller,
                    maxLength: _maxLength,
                    maxLines: 3,
                    minLines: 1,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_maxLength),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Escribe algo corto...',
                      border: InputBorder.none,
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                  // Contador vivo
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: length >= _maxLength
                          ? scheme.errorContainer
                          : (length > 40
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$length/$_maxLength',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: length >= _maxLength
                            ? scheme.onErrorContainer
                            : (length > 40
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                      backgroundColor: scheme.surfaceContainerHighest,
                      foregroundColor: scheme.onSurface,
                      side: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Guardar'),
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