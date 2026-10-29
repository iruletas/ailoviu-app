import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_providers.dart';

/// Bottom sheet para editar el estado propio ("cómo me siento ahora").
///
/// - Texto libre, máximo 60 caracteres.
/// - Emoji opcional elegido de un set chico.
/// - Se guarda con expiración de 24h.
/// - Contador vivo con cambio tonal (onSurfaceVariant → primary → error).
/// - Chips con morphing + spring scale.
/// - Botón "Guardar" se transforma en "Borrar estado" si vacío.
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
  String? _emoji;

  static const _emojis = ['💭', '💖', '😊', '😢', '😴', '🔥', '🌧️', '✨'];
  static const int _maxLength = 60;

  @override
  void initState() {
    super.initState();
    final current = ref.read(myStatusProvider);
    _controller = TextEditingController(text: current?.text ?? '');
    _emoji = current?.emoji;
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
          emoji: _emoji,
          authorDeviceId: deviceId,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final length = _controller.text.length;
    final isEmpty = _controller.text.trim().isEmpty;

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
            Text(
              '¿Cómo te sientes ahora?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
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
            const SizedBox(height: 20),

            // Emojis
            Text(
              'Emoji (opcional)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _emojis)
                  _EmojiChip(
                    emoji: e,
                    selected: _emoji == e,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        _emoji = _emoji == e ? null : e;
                      });
                    },
                  ),
              ],
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
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: Icon(
                      isEmpty
                          ? Icons.delete_outline_rounded
                          : Icons.check_rounded,
                      size: 18,
                    ),
                    label: Text(isEmpty ? 'Borrar estado' : 'Guardar'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                      backgroundColor:
                          isEmpty ? scheme.errorContainer : scheme.primary,
                      foregroundColor:
                          isEmpty ? scheme.onErrorContainer : scheme.onPrimary,
                    ),
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

class _EmojiChip extends StatefulWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _EmojiChip({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_EmojiChip> createState() => _EmojiChipState();
}

class _EmojiChipState extends State<_EmojiChip> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed
            ? 0.85
            : (widget.selected ? 1.15 : 1.0),
        duration: const Duration(milliseconds: 200),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(
              widget.selected ? 20 : 14,
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 22),
          ),
        ),
      ),
    );
  }
}