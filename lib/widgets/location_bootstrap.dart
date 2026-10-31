import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_providers.dart';

/// Dispara `refreshMyLocation()` al abrir la app y cada vez que
/// vuelve del background (con throttle).
///
/// No tiene UI: devuelve `SizedBox.shrink()`. Se monta una sola vez,
/// en `main_shell.dart`.
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
  Widget build(BuildContext context) {
    // Observar el deviceId. Cuando resuelve no-vacío, disparar el
    // primer refresh en post-frame (nunca durante build).
    final deviceIdAsync = ref.watch(myDeviceIdProvider);

    if (deviceIdAsync.hasValue && !_firstRunDone) {
      final id = deviceIdAsync.value ?? '';
      if (id.isNotEmpty) {
        _firstRunDone = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _attemptRefresh(force: false);
        });
      }
    }

    return const SizedBox.shrink();
  }
}