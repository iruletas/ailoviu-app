import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_providers.dart';

/// Dispara `refreshMyLocation()` al abrir la app y cada vez que
/// vuelve del background (con throttle). Se monta una sola vez en
/// `main_shell.dart`. El `AuthGate` garantiza que el árbol real
/// (y por ende este widget) solo se monte después de un splash
/// mínimo de 2s, dándole tiempo a `Geolocator` de engancharse.
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