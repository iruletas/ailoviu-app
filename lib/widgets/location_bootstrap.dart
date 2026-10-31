import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_providers.dart';

/// Dispara `refreshMyLocation()` al abrir la app y cada vez que
/// vuelve del background (con throttle).
///
/// No tiene UI: devuelve `SizedBox.shrink()`. Se monta una sola vez,
/// en `main_shell.dart`, para que su ciclo de vida sea el de la app
/// entera.
///
/// Reglas:
/// - No dispara nada hasta que `myDeviceIdProvider` resuelva (antes,
///   el `deviceId` sería `''` y `Geolocator` con deviceId vacío
///   rompe el primer frame — ese fue el bug de la pantalla negra).
/// - Al montarse (primer frame + deviceId listo): dispara refresh si
///   el usuario ya compartió ubicación antes. Si nunca compartió, no
///   hace nada (no queremos diálogo de permiso sorpresivo).
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previous = _lastLifecycle;
    _lastLifecycle = state;

    final cameFromBackground = previous == AppLifecycleState.paused ||
        previous == AppLifecycleState.hidden ||
        previous == AppLifecycleState.inactive;

    if (state == AppLifecycleState.resumed && cameFromBackground) {
      _attemptRefresh(force: false);
    }
  }

  /// Primer refresh: se dispara cuando el `deviceId` ya está listo.
  /// Si el provider tarda o falla, no se dispara (mejor no pedir
  /// ubicación sin identidad que romper el frame).
  Future<void> _onDeviceIdReady(String deviceId) async {
    if (!mounted || _firstRunDone || deviceId.isEmpty) return;
    _firstRunDone = true;
    await _attemptRefresh(force: false);
  }

  /// Intenta el refresh. Con [force] `false`, respeta el throttle y
  /// no pide permiso si nunca se compartió ubicación.
  Future<void> _attemptRefresh({required bool force}) async {
    if (!mounted) return;

    final deviceId = ref.read(myDeviceIdProvider).valueOrNull ?? '';
    if (deviceId.isEmpty) return; // todavía no hay identidad

    final now = DateTime.now();
    if (!force && _lastAttemptAt != null) {
      final elapsed = now.difference(_lastAttemptAt!);
      if (elapsed < widget.throttle) return;
    }
    _lastAttemptAt = now;

    try {
      final notifier = ref.read(locationsProvider.notifier);
      await notifier.refreshMyLocation();
    } catch (_) {
      // El refresh es un extra: nunca debe romper la app.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escucha la resolución del deviceId. Cuando llegue no-vacío,
    // dispara el primer refresh. `ref.listen` en build es seguro
    // porque solo se suscribe, no dispara rebuilds del árbol.
    ref.listen<String>(myDeviceIdProvider, (previous, next) {
      next.whenData((id) => _onDeviceIdReady(id));
    });

    // Caso ya resuelto (por si llegó antes de que este widget se
    // montara, cosa que no debería pasar pero por si acaso).
    final existing = ref.read(myDeviceIdProvider).valueOrNull;
    if (existing != null && existing.isNotEmpty && !_firstRunDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onDeviceIdReady(existing);
      });
    }

    return const SizedBox.shrink();
  }
}