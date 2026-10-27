import 'package:flutter/material.dart';
import 'main_shell.dart';

class AiloviuApp extends StatelessWidget {
  const AiloviuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ailoviu',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const MainShell(),
    );
  }

  ThemeData _buildTheme() {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.pinkAccent);
    return ThemeData(colorScheme: scheme, useMaterial3: true);
  }
}