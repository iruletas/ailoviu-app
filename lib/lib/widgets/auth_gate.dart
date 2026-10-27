import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_settings_providers.dart';
import '../screens/lock_screen.dart';

/// Envuelve la app con el gate de app-lock.
///
/// Comportamiento:
/// - Si `authSettings.loaded == false` → splash mínimo (evita
///   parpadeo de lock antes de leer prefs).
/// - Si `appLockEnabled == false` → deja pasar directo.
/// - Si `appLockEnabled == true` y `authSession.appUnlocked == false`
///   → muestra [LockScreen] hasta que el usuario se autentique.
/// - Si `appLockEnabled == true` y `appUnlocked == true` → deja pasar,
///   pero escucha el ciclo de vida para re-bloquear tras el timeout
///   configurado en background.
class AuthGate extends ConsumerStatefulWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

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
    final auth = ref.read(authSettingsProvider);
    if (!auth.appLockEnabled) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
        break;
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since == null) return;
        final timeout = auth.appLockTimeout;
        if (timeout == null) return;
        final elapsed = DateTime.now().difference(since);
        if (elapsed >= timeout) {
          ref.read(authSessionProvider.notifier).lockApp();
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authSettingsProvider);
    final session = ref.watch(authSessionProvider);

    if (!auth.loaded) {
      return const _AuthSplash();
    }

    if (!auth.appLockEnabled) {
      return widget.child;
    }

    if (!session.appUnlocked) {
      return const LockScreen();
    }

    return widget.child;
  }
}

class _AuthSplash extends StatelessWidget {
  const _AuthSplash();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}