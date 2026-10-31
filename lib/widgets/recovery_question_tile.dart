import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync_models.dart';
import '../providers/sync_providers.dart';
import '../services/linking_service.dart';
import 'map_feedback.dart';
import 'settings_components.dart';

final _hasRecoveryQuestionProvider = FutureProvider<bool>((ref) async {
  final question = await ref.watch(keyStoreProvider).getRecoveryQuestion();
  return question != null;
});

class RecoveryQuestionTile extends ConsumerWidget {
  const RecoveryQuestionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasQuestionAsync = ref.watch(_hasRecoveryQuestionProvider);
    final hasQuestion = hasQuestionAsync.valueOrNull ?? false;

    final bubbleBg = hasQuestion
        ? scheme.tertiaryContainer
        : scheme.secondaryContainer;
    final bubbleFg = hasQuestion
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
            boxShadow: hasQuestion
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
              hasQuestion ? Icons.help_rounded : Icons.help_outline_rounded,
              key: ValueKey(hasQuestion),
              size: 20,
              color: bubbleFg,
            ),
          ),
        ),
        title: 'Pregunta de recuperación',
        subtitle: hasQuestion
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
                    label: 'Configurada',
                    background: scheme.tertiaryContainer,
                    foreground: scheme.onTertiaryContainer,
                    bold: true,
                  ),
                ],
              )
            : MiniChip(
                label: 'Sin configurar',
                background: scheme.surfaceContainerHighest,
                foreground: scheme.onSurfaceVariant,
              ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: scheme.onSurfaceVariant,
        ),
        onTap: () async {
          HapticFeedback.lightImpact();
          final saved = await _showRecoveryQuestionDialog(context, ref);
          if (saved == true) {
            ref.invalidate(_hasRecoveryQuestionProvider);
          }
        },
      ),
    );
  }

  Future<bool?> _showRecoveryQuestionDialog(
    BuildContext context,
    WidgetRef ref,
  ) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, _, __) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: _RecoveryQuestionDialog(ref: ref),
      ),
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubicEmphasized,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _RecoveryQuestionDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _RecoveryQuestionDialog({required this.ref});

  @override
  ConsumerState<_RecoveryQuestionDialog> createState() =>
      _RecoveryQuestionDialogState();
}

class _RecoveryQuestionDialogState
    extends ConsumerState<_RecoveryQuestionDialog> {
  final _questionCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _qFocus = FocusNode();
  final _aFocus = FocusNode();
  bool _qFocused = false;
  bool _aFocused = false;
  bool _saving = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _qFocus.addListener(() {
      if (mounted) setState(() => _qFocused = _qFocus.hasFocus);
    });
    _aFocus.addListener(() {
      if (mounted) setState(() => _aFocused = _aFocus.hasFocus);
    });
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final q = await ref.read(keyStoreProvider).getRecoveryQuestion();
    if (!mounted || q == null) return;
    setState(() {
      _questionCtrl.text = q.questionPlain;
    });
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    _qFocus.dispose();
    _aFocus.dispose();
    super.dispose();
  }

  bool get _valid =>
      _questionCtrl.text.trim().isNotEmpty &&
      _answerCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() {
      _saving = true;
      _inlineError = null;
    });

    try {
      final linking = ref.read(linkingServiceProvider);
      final question = await linking.setRecoveryQuestion(
        questionPlain: _questionCtrl.text.trim(),
        answer: _answerCtrl.text.trim(),
      );

      // Propagar a otros miembros si hay.
      final group = await ref.read(linkingServiceProvider).snapshot();
      if (group.approvedPeerDeviceIds.isNotEmpty) {
        try {
          final sync = await ref.read(syncServiceProvider.future);
          await sync.enqueue(
            type: SyncType.recoveryQuestionUpdate,
            payload: {
              'questionPlain': question.questionPlain,
              'answerHash': question.answerHash,
              'answerSalt': question.answerSalt,
            },
          );
        } catch (_) {}
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
      MapFeedback.showSuccess(context, 'Pregunta guardada');
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _inlineError = 'No se pudo guardar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.help_rounded,
                        size: 28,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pregunta de recuperación',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Se usará para verificar tu identidad si olvidas tu PIN y necesitas recuperar tu cuenta en otro dispositivo.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: 'Pregunta',
                    hint: 'Ej. ¿Cómo se llama nuestra mascota?',
                    controller: _questionCtrl,
                    focusNode: _qFocus,
                    isFocused: _qFocused,
                    maxLines: 2,
                    onChanged: (_) => setState(() => _inlineError = null),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Respuesta',
                    hint: 'La respuesta que recordarás',
                    controller: _answerCtrl,
                    focusNode: _aFocus,
                    isFocused: _aFocused,
                    onChanged: (_) => setState(() => _inlineError = null),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _inlineError == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 16,
                                    color: scheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _inlineError!,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onErrorContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: (_valid && !_saving) ? _save : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: const StadiumBorder(),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    strokeCap: StrokeCap.round,
                                  ),
                                )
                              : const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isFocused ? scheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: maxLines,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}