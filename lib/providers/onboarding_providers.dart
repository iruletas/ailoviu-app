import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_provider.dart';

// ── Claves (prefijo onboarding.) ─────────────────────────────────────────
const _kCompleted = 'onboarding.completed';
const _kCompletedAt = 'onboarding.completedAt';
const _kLastStep = 'onboarding.lastStep';

/// Pasos del onboarding. El orden es el que se muestra en la UI.
///
/// Nota: no declaramos un getter `index` propio porque Dart ya lo tiene
/// implícito en los enums. Usamos `position` para el índice persistido
/// (que coincide con el implícito, pero es explícito y legible).
enum OnboardingStep {
  welcome,
  relationship,
  map,
  firebase,
  linking;

  /// Posición del paso dentro del enum. Es equivalente al `index`
  /// implícito, pero con nombre propio para dejar claro que se usa
  /// como índice de persistencia y de UI.
  int get position => OnboardingStep.values.indexOf(this);

  static OnboardingStep fromIndex(int i) {
    if (i < 0 || i >= OnboardingStep.values.length) {
      return OnboardingStep.welcome;
    }
    return OnboardingStep.values[i];
  }
}

/// Estado del onboarding en memoria + persistido.
class OnboardingState {
  /// `true` cuando el usuario terminó (o saltó) el onboarding completo.
  final bool completed;

  /// Cuándo se completó. `null` si nunca.
  final DateTime? completedAt;

  /// Último paso visto. Sirve para "reanudar" si el usuario cierra la
  /// app a la mitad del onboarding.
  final OnboardingStep lastStep;

  /// `false` hasta que `SharedPreferences` termine de cargar.
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