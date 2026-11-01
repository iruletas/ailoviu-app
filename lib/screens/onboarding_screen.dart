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
        OnboardingWelcomeStep(
          onNext: _next,
          onSkipAll: _finish,
        ),
        OnboardingRoleStep(
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
        OnboardingWelcomeStep(
          onNext: _next,
          onSkipAll: _finish,
        ),
        OnboardingRoleStep(
          onHostSelected: _next,
          onGuestSelected: _selectGuest,
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
      // Salta directo al escáner (índice 2 en la nueva lista de invitado)
      _currentStep = 2;
    });
    _pageController.jumpToPage(2);
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
    if (_isGuest && _currentStep == 2) {
      setState(() {
        _isGuest = false;
        _rebuildSteps();
        _currentStep = 1; // Vuelve al paso 2 (Rol)
      });
      _pageController.jumpToPage(1);
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
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _previous();
      },
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) {
          setState(() => _currentStep = i);
          HapticFeedback.selectionClick();
        },
        children: _steps,
      ),
    );
  }
}