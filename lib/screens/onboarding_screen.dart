import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/onboarding_providers.dart';
import '../widgets/onboarding_firebase_step.dart';
import '../widgets/onboarding_linking_step.dart';
import '../widgets/onboarding_map_step.dart';
import '../widgets/onboarding_relationship_step.dart';
import '../widgets/onboarding_role_step.dart';
import '../widgets/onboarding_welcome_step.dart';
import 'onboarding_welcome_relationship_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  bool _isGuest = false;

  // No usar 'late final'. Debe ser mutable para permitir el cambio de flujo.
  List<Widget> _steps = [];

  @override
  void initState() {
    super.initState();
    _rebuildSteps();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _rebuildSteps() {
    if (_isGuest) {
      _steps = [
        const OnboardingRoleStep(
          onHostSelected: _dummy,
          onGuestSelected: _dummy,
        ),
        OnboardingLinkingStep(
          isGuestFlow: true,
          onFinish: _finish,
          onBack: _previous,
        ),
      ];
    } else {
      _steps = [
        OnboardingRoleStep(
          onHostSelected: _next,
          onGuestSelected: _selectGuest,
        ),
        OnboardingWelcomeStep(
          onNext: _next,
          onSkipAll: _finish,
        ),
        OnboardingRelationshipStep(
          onNext: _next,
          onBack: _previous,
          onSkip: _next,
        ),
        OnboardingMapStep(
          onNext: _next,
          onBack: _previous,
          onSkip: _next,
        ),
        OnboardingFirebaseStep(
          onNext: _next,
          onBack: _previous,
          onSkip: _next,
        ),
        OnboardingLinkingStep(
          isGuestFlow: false,
          onFinish: _finish,
          onBack: _previous,
        ),
      ];
    }
  }

  void _dummy() {}

  void _selectGuest() {
    setState(() {
      _isGuest = true;
      _rebuildSteps();
      _currentStep = 1;
    });
    _pageController.jumpToPage(1);
    HapticFeedback.selectionClick();
  }

  void _goTo(int index) {
    if (index < 0 || index >= _steps.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  void _next() => _goTo(_currentStep + 1);

  void _previous() {
    // Si el invitado intenta retroceder desde el escáner, reseteamos el flujo
    if (_isGuest && _currentStep == 1) {
      setState(() {
        _isGuest = false;
        _rebuildSteps();
        _currentStep = 0;
      });
      _pageController.jumpToPage(0);
      HapticFeedback.selectionClick();
      return;
    }
    _goTo(_currentStep - 1);
  }

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).complete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const OnboardingWelcomeRelationshipScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _previous();
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) {
                setState(() => _currentStep = i);
                HapticFeedback.selectionClick();
              },
              children: _steps,
            ),
            
            // Indicador de progreso flotante
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _StepIndicator(
                    current: _currentStep,
                    total: _steps.length,
                  ),
                ),
              ),
            ),
          ],
        ),
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