import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_provider.dart';

// ── Claves (prefijo onboarding.) ─────────────────────────────────────────
const _kCompleted = 'onboarding.completed';
const _kCompletedAt = 'onboarding.completedAt';
const _kLastStep = 'onboarding.lastStep';

/// Pasos del onboarding. El orden es el que se muestra en la UI.
enum OnboardingStep {
  welcome,
  relationship,
  map,
  firebase,
  linking;

  int get index => OnboardingStep.values.indexOf(this);

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
  /// Es lo único que `app.dart` necesita leer para decidir qué mostrar.
  final bool completed;

  /// Cuándo se completó. `null` si nunca.
  final DateTime? completedAt;

  /// Último paso visto. Sirve para "reanudar" si el usuario cierra la
  /// app a la mitad del onboarding. `welcome` es el default.
  final OnboardingStep lastStep;

  /// `false` hasta que `SharedPreferences` termine de cargar. Evita
  /// que `app.dart` decida antes de tiempo y muestre un flash del
  /// onboarding a usuarios que ya lo completaron.
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

  /// Avanza el paso actual y lo persiste. Se llama cuando el usuario
  /// toca "Continuar" en un paso, o cuando el `PageView` cambia de página.
  Future<void> setStep(OnboardingStep step) async {
    if (state.lastStep == step) return;
    state = state.copyWith(lastStep: step);
    final prefs = await _prefsFuture;
    await prefs.setInt(_kLastStep, step.index);
  }

  /// Marca el onboarding como completado. Persiste el flag y la fecha.
  /// Después de esto, `app.dart` deja de mostrarlo.
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

  /// Vuelve a poner el onboarding como pendiente. Se llama desde
  /// Ajustes → "Repetir configuración inicial".
  ///
  /// **No borra** la configuración existente (relación, CARTO, Firebase,
  /// grupo vinculado). Solo hace que el onboarding se vuelva a mostrar.
  /// El usuario puede saltarse pasos que ya están configurados.
  Future<void> reset() async {
    state = state.copyWith(
      completed: false,
      lastStep: OnboardingStep.welcome,
    );
    final prefs = await _prefsFuture;
    await prefs.setBool(_kCompleted, false);
    await prefs.setInt(_kLastStep, 0);
    // No borramos _kCompletedAt: guarda cuándo se completó la última
    // vez, útil para debug y analytics locales.
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(ref.read(prefsProvider.future)),
);