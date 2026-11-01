import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/onboarding_providers.dart';
import '../providers/sync_providers.dart';
import 'firebase_credentials_card.dart';
import 'firebase_rules_card.dart';
import 'firebase_test_card.dart';
import 'onboarding_scaffold.dart';
import 'settings_components.dart';

class OnboardingFirebaseStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const OnboardingFirebaseStep({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  @override
  ConsumerState<OnboardingFirebaseStep> createState() =>
      _OnboardingFirebaseStepState();
}

enum _FirebaseSubStep { credentials, rules, test }

class _OnboardingFirebaseStepState
    extends ConsumerState<OnboardingFirebaseStep> {
  _FirebaseSubStep _subStep = _FirebaseSubStep.credentials;
  int _direction = 1;
  bool _hadConfigOnEntry = false;
  bool _testPassed = false;

  final _credentialsKey = GlobalKey<FirebaseCredentialsCardState>();
  
  // Estado para saber si la tarjeta de credenciales tiene texto
  bool _hasCredentialsText = false;
  bool _isSavingCredentials = false;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final raw = await ref.read(keyStoreProvider).getTransportConfig();
    if (!mounted) return;
    setState(() {
      _hadConfigOnEntry = raw != null;
      _hasCredentialsText = raw != null;
    });
  }

  void _goTo(_FirebaseSubStep step) {
    if (step == _subStep) return;
    HapticFeedback.selectionClick();
    setState(() {
      _direction = step.index > _subStep.index ? 1 : -1;
      _subStep = step;
      if (step != _FirebaseSubStep.test) _testPassed = false;
    });
  }

  void _onCredentialsSaved() {
    setState(() => _isSavingCredentials = false);
    _goTo(_FirebaseSubStep.rules);
  }

  Future<void> _handlePrimaryAction() async {
    if (_subStep == _FirebaseSubStep.credentials) {
      if (!_hasCredentialsText) {
        // Si está vacío, no hace nada (el botón está deshabilitado en apariencia)
        return;
      }
      setState(() => _isSavingCredentials = true);
      _credentialsKey.currentState?.validateAndSave();
      
    } else if (_subStep == _FirebaseSubStep.rules) {
      _goTo(_FirebaseSubStep.test);
    } else if (_subStep == _FirebaseSubStep.test) {
      if (_testPassed) {
        HapticFeedback.mediumImpact();
        widget.onNext();
      }
    }
  }

  Future<void> _confirmSkipWithWarning() async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: _SkipWarningDialog(
          onConfirm: () => Navigator.pop(context, true),
          onCancel: () => Navigator.pop(context, false),
        ),
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

    if (confirmed == true) widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return OnboardingScaffold(
      step: OnboardingStep.firebase,
      onSkip: _confirmSkipWithWarning,
      bottomAction: _buildBottomBar(scheme, theme),
      child: SingleChildScrollView(
        // Key para mantener el scroll estable
        key: const PageStorageKey('firebase_scroll'),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 44,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Firebase',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Este paso es el más técnico, pero también el más importante: '
              'aquí es donde Ailoviu se vuelve un espacio privado de verdad. '
              'Lo que se manden viaja cifrado; ni siquiera el servidor que '
              'lo transporta puede leerlo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            _SubStepIndicator(
              current: _subStep,
              onTap: (step) {
                final canGoBack = step.index < _subStep.index;
                if (canGoBack) _goTo(step);
              },
            ),
            const SizedBox(height: 20),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeInOutCubicEmphasized,
              switchOutCurve: Curves.easeInOutCubicEmphasized,
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubicEmphasized,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0.06 * _direction, 0),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
              child: _buildSubStep(),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSubStep() {
    switch (_subStep) {
      case _FirebaseSubStep.credentials:
        return Column(
          key: const ValueKey('credentials'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BentoCard(
              child: const TonalMicroHeader(
                icon: Icons.security_rounded,
                title: '¿Por qué hacemos esto?',
                description:
                    'Al usar tu propio proyecto de Firebase, los datos no pasan '
                    'por nuestros servidores. La base de datos es tuya, y nosotros '
                    'solo te recomendamos las reglas de seguridad para que nadie '
                    'más pueda entrar. La llave de cifrado solo la tienen los '
                    'dispositivos vinculados. Nosotros no podemos ver nada.',
              ),
            ),
            const SizedBox(height: 16),
            
            FirebaseCredentialsCard(
              key: _credentialsKey,
              initiallyConfigured: _hadConfigOnEntry,
              onSaved: _onCredentialsSaved,
              onStateChanged: (hasText) {
                if (_hasCredentialsText != hasText) {
                  setState(() => _hasCredentialsText = hasText);
                }
              },
            ),
          ],
        );
      case _FirebaseSubStep.rules:
        return Column(
          key: const ValueKey('rules'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FirebaseRulesCard(),
            const SizedBox(height: 16),
            const _NextStepHint(
              icon: Icons.check_circle_outline_rounded,
              text:
                  'Cuando hayas publicado las reglas en Console, toca '
                  '"Ya publiqué las reglas" abajo.',
            ),
          ],
        );
      case _FirebaseSubStep.test:
        return Column(
          key: const ValueKey('test'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FirebaseTestCard(
              onResult: (passed) {
                setState(() {
                  _testPassed = passed;
                });
              },
            ),
            if (!_testPassed) ...[
              const SizedBox(height: 16),
              const _NextStepHint(
                icon: Icons.info_outline_rounded,
                text:
                    'Necesitas pasar el test para continuar. Si algo falla, '
                    'el mensaje te dice exactamente qué revisar en Console.',
              ),
            ],
          ],
        );
    }
  }

  Widget _buildBottomBar(ColorScheme scheme, ThemeData theme) {
    final isLastSubStep = _subStep == _FirebaseSubStep.test;
    
    // Etiqueta e icono dinámicos
    String label;
    IconData icon;
    bool canContinue = true;

    if (_subStep == _FirebaseSubStep.credentials) {
      if (!_hasCredentialsText) {
        label = 'Pega el archivo arriba';
        icon = Icons.arrow_upward_rounded;
        canContinue = false; // Deshabilitado si no hay texto
      } else {
        label = 'Validar y guardar';
        icon = Icons.check_rounded;
        canContinue = !_isSavingCredentials;
      }
    } else if (_subStep == _FirebaseSubStep.rules) {
      label = 'Ya publiqué las reglas';
      icon = Icons.arrow_forward_rounded;
    } else {
      label = _testPassed ? 'Continuar' : 'Falta pasar el test';
      icon = _testPassed ? Icons.check_rounded : Icons.lock_outline_rounded;
      canContinue = _testPassed;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (_subStep == _FirebaseSubStep.credentials) {
                widget.onBack();
              } else {
                _goTo(_FirebaseSubStep.values[_subStep.index - 1]);
              }
            },
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurface,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              height: 48,
              decoration: BoxDecoration(
                color: canContinue
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: canContinue ? _handlePrimaryAction : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: _isSavingCredentials
                          ? SizedBox(
                              key: const ValueKey('busy'),
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                strokeCap: StrokeCap.round,
                                color: scheme.onPrimary,
                              ),
                            )
                          : Row(
                              key: ValueKey('$label-$canContinue'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icon,
                                  size: 20,
                                  color: canContinue
                                      ? scheme.onPrimary
                                      : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  label,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: canContinue
                                        ? scheme.onPrimary
                                        : scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Diálogo de Advertencia ───────────────────────────────────────────
class _SkipWarningDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _SkipWarningDialog({required this.onConfirm, required this.onCancel});

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
              color: scheme.surfaceContainerLow.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 32,
                    color: scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Saltar Firebase?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'La app funcionará solo en este celular. No podrás '
                  'compartir estados, ubicaciones ni zumbidos con tu '
                  'pareja, y no se podrá recuperar la cuenta si pierdes '
                  'este teléfono.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Puedes configurarlo después desde Ajustes → Conexiones.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: onCancel,
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
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          onConfirm();
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        ),
                        child: const Text('Saltar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Indicador de Sub-pasos ───────────────────────────────────────────
class _SubStepIndicator extends StatelessWidget {
  final _FirebaseSubStep current;
  final ValueChanged<_FirebaseSubStep> onTap;

  const _SubStepIndicator({
    required this.current,
    required this.onTap,
  });

  static const _labels = ['Credenciales', 'Reglas', 'Probar'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Row(
      children: [
        for (int i = 0; i < _FirebaseSubStep.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            flex: i == current.index ? 3 : 2,
            child: _SubStepChip(
              label: _labels[i],
              isActive: i == current.index,
              isCompleted: i < current.index,
              canTap: i < current.index,
              onTap: () => onTap(_FirebaseSubStep.values[i]),
              scheme: scheme,
              theme: theme,
            ),
          ),
        ],
      ],
    );
  }
}

class _SubStepChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final bool isCompleted;
  final bool canTap;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final ThemeData theme;

  const _SubStepChip({
    required this.label,
    required this.isActive,
    required this.isCompleted,
    required this.canTap,
    required this.onTap,
    required this.scheme,
    required this.theme,
  });

  @override
  State<_SubStepChip> createState() => _SubStepChipState();
}

class _SubStepChipState extends State<_SubStepChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final bg = widget.isActive
        ? scheme.primary
        : (widget.isCompleted
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest);
    final fg = widget.isActive
        ? scheme.onPrimary
        : (widget.isCompleted
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant);

    final radius = widget.isActive ? 16.0 : 12.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.canTap
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.canTap
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.canTap
          ? () => setState(() => _pressed = false)
          : null,
      onTap: widget.canTap
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: widget.isCompleted
                  ? Container(
                      key: const ValueKey('check'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Text(
                      widget.label,
                      key: const ValueKey('label'),
                      style: widget.theme.textTheme.labelSmall!.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NextStepHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _NextStepHint({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 16,
              color: scheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onTertiaryContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}