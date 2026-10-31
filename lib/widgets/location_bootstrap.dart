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
///   rompe el primer frame).
/// - Al montarse (primer frame + deviceId listo): dispara refresh si
///   el usuario ya compartió ubicación antes. Si nunca compartió, no
///   hace nada (no queremos diálogo de permiso sorpresivo).
/// - En cada `resumed` desde `paused`/`inactive`/`hidden`: dispara
///   refresh, pero solo si pasaron al menos [throttle] desde el
///   último intento.
/// - No bloquea la UI: `refreshMyLocation()` corre en background y
///   actualiza el provider cuando termina.
class LocationBootstrap extends ConsumerStatefulWidget {
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
  ProviderSubscription<AsyncValue<String>>? _deviceIdSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Escucha la resolución del deviceId. `listenManual` funciona
    // con `FutureProvider` porque recibe `AsyncValue<String>`.
    _deviceIdSub = ref.listenManual<AsyncValue<String>>(
      myDeviceIdProvider,
      (previous, next) {
        switch (next) {
          case AsyncData(:final value):
            _onDeviceIdReady(value);
            break;
          case AsyncError():
          case AsyncLoading():
            break;
        }
      },
    );

    // Por si el deviceId ya estaba resuelto antes de este frame
    // (raro, pero pasa con `KeepAlive` o si otro widget ya forzó el
    // provider). `ref.read` no rompe.
    final existing = ref.read(myDeviceIdProvider).valueOrNull;
    if (existing != null && existing.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onDeviceIdReady(existing);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deviceIdSub?.close();
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

  Future<void> _onDeviceIdReady(String deviceId) async {
    if (!mounted || _firstRunDone || deviceId.isEmpty) return;
    _firstRunDone = true;
    await _attemptRefresh(force: false);
  }

  Future<void> _attemptRefresh({required bool force}) async {
    if (!mounted) return;

    final deviceId = ref.read(myDeviceIdProvider).valueOrNull ?? '';
    if (deviceId.isEmpty) return;

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
  Widget build(BuildContext context) => const SizedBox.shrink();
}