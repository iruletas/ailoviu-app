import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/onboarding_providers.dart';
import '../widgets/onboarding_firebase_step.dart';
import '../widgets/onboarding_linking_step.dart';
import '../widgets/onboarding_map_step.dart';
import '../widgets/onboarding_relationship_step.dart';
import '../widgets/onboarding_welcome_step.dart';
import 'onboarding_welcome_relationship_screen.dart';

/// Onboarding sin selección de rol.
///
/// El rol se deduce de lo que hace la persona:
/// - Si toca "Empezar", configura el espacio (nombres, mapa, Firebase) y
///   muestra el QR. Es quien configura; su nombre es el primer campo.
/// - Si toca "Ya tengo un código QR", solo escanea y se une.
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
          onJoin: _startAsGuest,
          onSkipAll: _finish,
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
          onJoin: _startAsGuest,
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

  void _startAsGuest() {
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
    // Si quien escanea retrocede, vuelve a la bienvenida.
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
