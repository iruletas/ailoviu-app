import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/onboarding_providers.dart';
import 'onboarding_scaffold.dart';
import 'settings_components.dart';

/// Paso 1: Bienvenida y contexto.
class OnboardingWelcomeStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  /// Quien ya tiene un QR (no configura nada, solo escanea).
  final VoidCallback onJoin;
  final VoidCallback onSkipAll;

  const OnboardingWelcomeStep({
    super.key,
    required this.onNext,
    required this.onJoin,
    required this.onSkipAll,
  });

  @override
  ConsumerState<OnboardingWelcomeStep> createState() =>
      _OnboardingWelcomeStepState();
}

class _OnboardingWelcomeStepState
    extends ConsumerState<OnboardingWelcomeStep>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _glowController;
  late final Animation<double> _heartScale;

  bool _pressed = false;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.4, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 40,
      ),
    ]).animate(_entranceController);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleNext() {
    HapticFeedback.mediumImpact();
    widget.onNext();
  }

  Future<void> _confirmSkipAll() async {
    HapticFeedback.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 28,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Saltar la configuración?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'La app funcionará solo en este celular hasta que configures '
                  'el espacio y vincules a tu amor.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
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
                          Navigator.pop(context, true);
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
        );
      },
    );

    if (confirmed == true) widget.onSkipAll();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return OnboardingScaffold(
      step: OnboardingStep.welcome,
      customStepNumber: 1,
      showSkip: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),

          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _heartScale,
                _glowController,
              ]),
              builder: (context, child) {
                final glowT = _glowController.value;
                final blur = 20 + glowT * 14;
                final spread = 1 + glowT * 4;
                final alpha = 0.24 + glowT * 0.16;

                return Transform.scale(
                  scale: _heartScale.value,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: alpha),
                          blurRadius: blur,
                          spreadRadius: spread,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 44,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Bienvenidos a Ailoviu',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Este es su rincón. Lo que compartan viaja cifrado '
            'y nadie más puede leerlo.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // ── Tarjeta Bento de Privacidad ──────────────────────────────
          BentoCard(
            child: const TonalMicroHeader(
              icon: Icons.shield_rounded,
              title: 'Privacidad de verdad',
              description:
                  'El primero en abrir la app deja todo listo y muestra un QR. '
                  'Tu amor solo lo escanea.',
            ),
          ),
          const SizedBox(height: 40),

          // ── Botón principal con compresión física ────────────────────
          AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
            child: Listener(
              onPointerDown: (_) => setState(() => _pressed = true),
              onPointerUp: (_) => setState(() => _pressed = false),
              onPointerCancel: (_) => setState(() => _pressed = false),
              child: FilledButton.icon(
                onPressed: _handleNext,
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: const Text('Empezar'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              widget.onJoin();
            },
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            label: const Text('Ya tengo un código QR'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _confirmSkipAll,
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              shape: const StadiumBorder(),
            ),
            child: const Text('Saltar configuración'),
          ),
        ],
      ),
    );
  }
}