import 'package:flutter/material.dart';

void main() {
  runApp(const AiloviuApp());
}

class AiloviuApp extends StatelessWidget {
  const AiloviuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ailoviu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
      home: const PantallaInicio(),
    );
  }
}

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ailoviu'),
      ),
      body: const Center(
        child: Text(
          '¡Hola, nosotros!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}