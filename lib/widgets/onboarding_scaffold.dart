import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/onboarding_providers.dart';

/// Chrome común del onboarding.
///
/// Provee:
/// - Fondo con dos esferas tonales radiales (estático, sin blur costoso).
/// - Barra superior con indicador de pasos por **píldoras expresivas**
///   (5 segmentos, el activo se expande elásticamente) y botón "Saltar".
/// - Contenido scrollable con padding consistente.
/// - Barra inferior opcional para acciones primarias.
///
/// **No tiene lógica de negocio.** Solo pinta el chrome y delega los
/// callbacks al padre.
class OnboardingScaffold extends StatelessWidget {
  final OnboardingStep step;
  final bool showSkip;
  final VoidCallback? onSkip;
  final Widget child;
  final Widget? bottomAction;

  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.child,
    this.showSkip = true,
    this.onSkip,
    this.bottomAction,
  });

  static const int _totalSteps = 5;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // ── Fondo con esferas tonales estáticas ────────────────────
          // Dos círculos radiales suaves en esquinas opuestas. Sin
          // BackdropFilter (caro en Android medio). Sin animación
          // dependiente del paso (sería lógica en la pantalla).
          Positioned(
            top: -120,
            right: -120,
            child: _AmbientOrb(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              size: 320,
            ),
          ),
          Positioned(
            bottom: -140,
            left: -140,
            child: _AmbientOrb(
              color: scheme.tertiaryContainer.withValues(alpha: 0.45),
              size: 360,
            ),
          ),

          // ── Contenido ──────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  currentStep: step.index + 1,
                  totalSteps: _totalSteps,
                  showSkip: showSkip,
                  onSkip: onSkip,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: child,
                  ),
                ),
                if (bottomAction != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: bottomAction!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Esfera radial suave usada como capa ambiental de fondo.
///
/// Sin `BackdropFilter`: usa un `RadialGradient` que se desvanece a
/// transparente, lo cual es prácticamente gratis de renderizar.
class _AmbientOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _AmbientOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool showSkip;
  final VoidCallback? onSkip;

  const _TopBar({
    required this.currentStep,
    required this.totalSteps,
    required this.showSkip,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StepBadge(
                current: currentStep,
                total: totalSteps,
                scheme: scheme,
                theme: theme,
              ),
              const Spacer(),
              if (showSkip)
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onSkip?.call();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    shape: const StadiumBorder(),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Saltar'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _SegmentedStepIndicator(
            currentStep: currentStep,
            totalSteps: totalSteps,
          ),
        ],
      ),
    );
  }
}

/// Chip tonal que muestra "Paso X de 5". Animado al cambiar de paso.
class _StepBadge extends StatelessWidget {
  final int current;
  final int total;
  final ColorScheme scheme;
  final ThemeData theme;

  const _StepBadge({
    required this.current,
    required this.total,
    required this.scheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          );
        },
        child: Text(
          'Paso $current de $total',
          key: ValueKey(current),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

/// Indicador de pasos por píldoras: 5 segmentos, el activo se expande
/// elásticamente (`flex: 3` vs `flex: 1`).
///
/// Es la forma M3E de mostrar progreso de onboarding (segmentos
/// expresivos, no barra de carga).
class _SegmentedStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _SegmentedStepIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 6,
      child: Row(
        children: [
          for (int i = 0; i < totalSteps; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              flex: i == currentStep - 1 ? 3 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: i < currentStep
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}