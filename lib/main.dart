import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/background_sync.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Canal de comunicación entre la app y el servicio en segundo plano.
  FlutterForegroundTask.initCommunicationPort();

  runApp(const ProviderScope(child: AiloviuApp()));

  // Con pareja y transporte configurados, deja corriendo el servicio
  // que recibe mensajes con la app cerrada.
  unawaited(BackgroundSyncService.bootstrap());
}
