import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'providers/settings_providers.dart';
import 'screens/main_shell.dart';

class AiloviuApp extends ConsumerWidget {
  const AiloviuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

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
      home: const MainShell(),
    );
  }
}