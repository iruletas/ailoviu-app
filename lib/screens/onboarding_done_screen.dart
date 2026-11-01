import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_shapes/m3e_shapes.dart';

import '../widgets/auth_gate.dart';
import '../widgets/main_shell_placeholder.dart';

/// Pantalla final del onboarding.
///
/// Muestra un corazón con glow pulsante, un mensaje de cierre, y un
/// botón con compresión física que lleva al shell principal.
///
/// **Solo arma.** No tiene lógica de negocio.
class OnboardingDoneScreen extends ConsumerStatefulWidget {
  const OnboardingDoneScreen({super.key});

  @override
  ConsumerState<OnboardingDoneScreen> createState() =>
      _OnboardingDoneScreenState();
}

class _OnboardingDoneScreenState extends ConsumerState<OnboardingDoneScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _glowController;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  bool _buttonPressed = false;

  @override
  void initState() {
    super.initState();

    // Entrada: rebote elástico del corazón + fade del texto.
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = TweenSequence<double>([
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
    _fade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    // Glow pulsante: respiración continua mientras el usuario lee.
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _entranceController.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _enterApp() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const AuthGate(child: MainShellPlaceholder()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Corazón + glow pulsante.
              AnimatedBuilder(
                animation: Listenable.merge([
                  _scale,
                  _glowController,
                ]),
                builder: (context, child) {
                  final glowT = _glowController.value;
                  final blurRadius = 24 + glowT * 12;
                  final spreadRadius = 2 + glowT * 4;
                  final glowAlpha = 0.28 + glowT * 0.14;

                  return Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary
                                .withValues(alpha: glowAlpha),
                            blurRadius: blurRadius,
                            spreadRadius: spreadRadius,
                          ),
                        ],
                      ),
                      child: Center(
                        child: M3EClip(
                          shape: M3EShape.heart,
                          child: ColoredBox(
                            color: scheme.primary,
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: Icon(
                                Icons.check_rounded,
                                size: 44,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    Text(
                      'Todo listo',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Ailoviu está configurada para ti y para los tuyos. '
                        'Lo que compartan viaja cifrado: nadie más puede '
                        'leerlo, ni siquiera nosotros.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FadeTransition(
                opacity: _fade,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => setState(() => _buttonPressed = true),
                  onTapUp: (_) => setState(() => _buttonPressed = false),
                  onTapCancel: () => setState(() => _buttonPressed = false),
                  onTap: _enterApp,
                  child: AnimatedScale(
                    scale: _buttonPressed ? 0.97 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    curve: _buttonPressed
                        ? Curves.easeOutCubic
                        : Curves.easeOutBack,
                    child: FilledButton.icon(
                      onPressed: _enterApp,
                      icon: const Icon(Icons.favorite_rounded, size: 20),
                      label: const Text('Entrar a Ailoviu'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}