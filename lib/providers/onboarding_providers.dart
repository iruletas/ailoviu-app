import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_provider.dart';

const _kCompleted = 'onboarding.completed';
const _kCompletedAt = 'onboarding.completedAt';
const _kLastStep = 'onboarding.lastStep';

enum OnboardingStep {
  welcome,
  relationship,
  map,
  firebase,
  linking;

  int get position => OnboardingStep.values.indexOf(this);

  static OnboardingStep fromIndex(int i) {
    if (i < 0 || i >= OnboardingStep.values.length) {
      return OnboardingStep.welcome;
    }
    return OnboardingStep.values[i];
  }
}

class OnboardingState {
  final bool completed;
  final DateTime? completedAt;
  final OnboardingStep lastStep;
  final bool loaded;

  const OnboardingState({
    this.completed = false,
    this.completedAt,
    this.lastStep = OnboardingStep.welcome,
    this.loaded = false,
  });

  OnboardingState copyWith({
    bool? completed,
    DateTime? completedAt,
    OnboardingStep? lastStep,
    bool? loaded,
  }) {
    return OnboardingState(
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      lastStep: lastStep ?? this.lastStep,
      loaded: loaded ?? this.loaded,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier(this._prefsFuture) : super(const OnboardingState()) {
    _load();
  }

  final Future<SharedPreferences> _prefsFuture;

  Future<void> _load() async {
    final prefs = await _prefsFuture;

    final completed = prefs.getBool(_kCompleted) ?? false;
    final completedAtStr = prefs.getString(_kCompletedAt);
    final lastStepIndex = prefs.getInt(_kLastStep) ?? 0;

    state = OnboardingState(
      completed: completed,
      completedAt:
          completedAtStr != null ? DateTime.tryParse(completedAtStr) : null,
      lastStep: OnboardingStep.fromIndex(lastStepIndex),
      loaded: true,
    );
  }

  Future<void> setStep(OnboardingStep step) async {
    if (state.lastStep == step) return;
    state = state.copyWith(lastStep: step);
    final prefs = await _prefsFuture;
    await prefs.setInt(_kLastStep, step.position);
  }

  Future<void> complete() async {
    final now = DateTime.now();
    state = state.copyWith(
      completed: true,
      completedAt: now,
    );
    final prefs = await _prefsFuture;
    await prefs.setBool(_kCompleted, true);
    await prefs.setString(_kCompletedAt, now.toIso8601String());
  }

  Future<void> reset() async {
    state = state.copyWith(
      completed: false,
      lastStep: OnboardingStep.welcome,
    );
    final prefs = await _prefsFuture;
    await prefs.setBool(_kCompleted, false);
    await prefs.setInt(_kLastStep, 0);
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(ref.read(prefsProvider.future)),
);