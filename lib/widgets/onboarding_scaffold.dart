import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/onboarding_providers.dart';

/// Chrome común del onboarding.
class OnboardingScaffold extends StatelessWidget {
  final OnboardingStep step;
  final bool showSkip;
  final VoidCallback? onSkip;
  final Widget child;
  final Widget? bottomAction;
  
  /// El índice visual (1-based). Si es null, se calcula del `step`.
  /// Útil para flujos con menos pasos (p. ej. quien solo escanea un QR).
  final int? customStepNumber;
  
  /// El total visual. Si es null, se usa 5.
  final int? customTotalSteps;

  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.child,
    this.showSkip = true,
    this.onSkip,
    this.bottomAction,
    this.customStepNumber,
    this.customTotalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    // Si no nos pasan un número custom, calculamos el estándar.
    // welcome=1, relationship=2, map=3, firebase=4, linking=5
    final currentStep = customStepNumber ?? (step.position + 1);
    final totalSteps = customTotalSteps ?? 5;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // Fondo con esferas
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

          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  currentStep: currentStep,
                  totalSteps: totalSteps,
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
              colors: [color, color.withValues(alpha: 0.0)],
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
      child: Row(
        children: [
          // Texto de paso
          Container(
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
                'Paso $currentStep de $totalSteps',
                key: ValueKey(currentStep),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          
          const Spacer(),
          
          // Indicador de puntitos
          _StepIndicator(
            current: currentStep - 1, // 0-based
            total: totalSteps,
          ),

          const Spacer(),

          // Botón Saltar
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
            )
          else
            const SizedBox(width: 60), // Espacio para mantener centrado
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: i == current ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == current
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}