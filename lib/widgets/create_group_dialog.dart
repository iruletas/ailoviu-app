import 'package:flutter/material.dart';

import 'linking_labeled_field.dart';

class CreateGroupFormResult {
  final String displayName;
  final String questionPlain;
  final String answer;

  const CreateGroupFormResult({
    required this.displayName,
    required this.questionPlain,
    required this.answer,
  });
}

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _nameCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _questionCtrl.text.trim().isNotEmpty &&
      _answerCtrl.text.trim().isNotEmpty;

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
                        Icons.group_add_rounded,
                        size: 28,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Crear grupo',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tu pregunta y respuesta de recuperación permiten '
                    'recuperar tu cuenta si cambias de teléfono.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  LinkingLabeledField(
                    label: 'Tu nombre',
                    hint: 'Ej. Ana',
                    controller: _nameCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  LinkingLabeledField(
                    label: 'Pregunta de recuperación',
                    hint: 'Ej. ¿Cómo se llama nuestra mascota?',
                    controller: _questionCtrl,
                    maxLines: 2,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  LinkingLabeledField(
                    label: 'Respuesta',
                    hint: 'La respuesta que recordarás',
                    controller: _answerCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
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
                          onPressed: _valid
                              ? () => Navigator.of(context).pop(
                                    CreateGroupFormResult(
                                      displayName: _nameCtrl.text.trim(),
                                      questionPlain:
                                          _questionCtrl.text.trim(),
                                      answer: _answerCtrl.text.trim(),
                                    ),
                                  )
                              : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Crear'),
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