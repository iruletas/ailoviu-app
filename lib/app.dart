import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'providers/onboarding_providers.dart';
import 'providers/settings_providers.dart';
import 'providers/sync_providers.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/auth_gate.dart';

class AiloviuApp extends ConsumerWidget {
  const AiloviuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantener vivo el router de sync durante toda la vida de la app.
    ref.watch(syncRouterProvider);

    final settings = ref.watch(settingsProvider);
    final onboarding = ref.watch(onboardingProvider);

    // Mientras SharedPreferences carga, mostramos el shell (que ya
    // tiene su propio splash con AuthGate). Evita un flash del
    // onboarding a usuarios que ya lo completaron.
    final showOnboarding = onboarding.loaded && !onboarding.completed;

    return MaterialApp(
      title: 'Ailoviu',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(
        brightness: Brightness.light,
        seed: settings.seedColor,
      ),
      darkTheme: buildTheme(
        brightness: Brightness.dark,
        seed: settings.seedColor,
        amoled: settings.amoled,
      ),
      themeMode: settings.themeMode,
      home: showOnboarding
          ? const OnboardingScreen()
          : const AuthGate(child: MainShell()),
    );
  }
}