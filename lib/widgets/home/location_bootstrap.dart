import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/home_providers.dart';

/// Dispara `refreshMyLocation()` al abrir la app y cada vez que
/// vuelve del background (con throttle).
///
/// No tiene UI: devuelve `SizedBox.shrink()`. Se monta una sola vez,
/// en `main_shell.dart`, para que su ciclo de vida sea el de la app
/// entera.
///
/// Reglas:
/// - Al montarse (primer frame): dispara refresh si el usuario ya
///   compartió ubicación antes. Si nunca compartió, no hace nada
///   (no queremos diálogo de permiso sorpresivo al primer arranque).
/// - En cada `resumed` desde `paused`/`inactive`/`hidden`: dispara
///   refresh, pero solo si pasaron al menos [throttle] desde el
///   último intento. Evita spam si el usuario alterna apps rápido.
/// - No bloquea la UI: `refreshMyLocation()` corre en background y
///   actualiza el provider cuando termina.
class LocationBootstrap extends ConsumerStatefulWidget {
  /// Tiempo mínimo entre refrescos al volver del background.
  final Duration throttle;

  const LocationBootstrap({
    super.key,
    this.throttle = const Duration(seconds: 60),
  });

  @override
  ConsumerState<LocationBootstrap> createState() =>
      _LocationBootstrapState();
}

class _LocationBootstrapState extends ConsumerState<LocationBootstrap>
    with WidgetsBindingObserver {
  DateTime? _lastAttemptAt;
  bool _firstRunDone = false;
  AppLifecycleState? _lastLifecycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onFirstRun());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _onFirstRun() async {
    if (!mounted || _firstRunDone) return;
    _firstRunDone = true;
    await _attemptRefresh(force: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previous = _lastLifecycle;
    _lastLifecycle = state;

    // Solo disparar cuando pasamos de background/inactive/hidden a
    // resumed. Ignorar el primer `resumed` (lo cubre _onFirstRun) y
    // los ciclos paused ↔ inactive internos.
    final cameFromBackground = previous == AppLifecycleState.paused ||
        previous == AppLifecycleState.hidden ||
        previous == AppLifecycleState.inactive;

    if (state == AppLifecycleState.resumed && cameFromBackground) {
      _attemptRefresh(force: false);
    }
  }

  /// Intenta el refresh. Con [force] `false`, respeta el throttle y
  /// no pide permiso si nunca se compartió ubicación.
  Future<void> _attemptRefresh({required bool force}) async {
    if (!mounted) return;

    final now = DateTime.now();
    if (!force && _lastAttemptAt != null) {
      final elapsed = now.difference(_lastAttemptAt!);
      if (elapsed < widget.throttle) return;
    }
    _lastAttemptAt = now;

    try {
      final notifier = ref.read(locationsProvider.notifier);
      // refreshMyLocation() ya sabe decidir si pedir permiso o no
      // (no lo hace si nunca se compartió). Es fire-and-forget: no
      // bloqueamos el hilo de UI esperando el GPS.
      await notifier.refreshMyLocation();
    } catch (_) {
      // El refresh es un extra: nunca debe romper la app. Si falla
      // (sin permiso, sin GPS, sin red), se reintenta en el próximo
      // resume.
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}