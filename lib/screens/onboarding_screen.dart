import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/onboarding_providers.dart';
import '../widgets/onboarding_firebase_step.dart';
import '../widgets/onboarding_linking_step.dart';
import '../widgets/onboarding_map_step.dart';
import '../widgets/onboarding_relationship_step.dart';
import '../widgets/onboarding_welcome_step.dart';
import 'onboarding_welcome_relationship_screen.dart';

/// Pantalla que orquesta el onboarding de 5 pasos.
///
/// **Solo arma.** Toda la lógica vive dentro de cada widget de paso.
/// Esta pantalla solo decide qué paso mostrar, avanza/retrocede el
/// `PageView`, persiste el paso actual y navega al terminar.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final savedStep = ref.read(onboardingProvider).lastStep.index;
    _currentIndex = savedStep;
    _pageController = PageController(initialPage: savedStep);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= OnboardingStep.values.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      // `fastOutSlowIn` es la curva estándar de M3 para transiciones de
      // pantalla completa.
      curve: Curves.fastOutSlowIn,
    );
  }

  void _next() => _goTo(_currentIndex + 1);

  void _previous() => _goTo(_currentIndex - 1);

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
    final steps = <Widget>[
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
        onFinish: _finish,
        onBack: _previous,
      ),
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _previous();
      },
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) {
          setState(() => _currentIndex = i);
          ref
              .read(onboardingProvider.notifier)
              .setStep(OnboardingStep.fromIndex(i));
        },
        children: steps,
      ),
    );
  }
}