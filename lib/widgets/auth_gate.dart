import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_shapes/m3e_shapes.dart';

import '../providers/auth_settings_providers.dart';
import '../screens/lock_screen.dart';

/// Envuelve la app con el gate de app-lock.
///
/// - `loaded == false` → splash mínimo (evita parpadeo de lock).
/// - `appLockEnabled == false` → deja pasar directo.
/// - `appLockEnabled == true` y `appUnlocked == false` → LockScreen.
/// - `appLockEnabled == true` y `appUnlocked == true` → deja pasar,
///   con re-bloqueo tras `appLockTimeout` si se configuró.
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
          HapticFeedback.mediumImpact();
          ref.read(authSessionProvider.notifier).lockApp();
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  String _contentKey(AppAuthSettings auth, AuthSession session) {
    if (!auth.loaded) return 'splash';
    if (!auth.appLockEnabled) return 'app';
    if (!session.appUnlocked) return 'lock';
    return 'app';
  }

  Widget _contentFor(AppAuthSettings auth, AuthSession session) {
    if (!auth.loaded) return const _AuthSplash();
    if (!auth.appLockEnabled) return widget.child;
    if (!session.appUnlocked) return const LockScreen();
    return widget.child;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authSettingsProvider);
    final session = ref.watch(authSessionProvider);
    final key = _contentKey(auth, session);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeInOutCubicEmphasized,
      switchOutCurve: Curves.easeInOutCubicEmphasized,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubicEmphasized,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(key),
        child: _contentFor(auth, session),
      ),
    );
  }
}

/// Splash de arranque: squircle tonal con pulso de marca y progress
/// M3E en el centro. No es una pantalla completa: es el estado
/// "esperando prefs" para evitar parpadeos antes de decidir el gate.
class _AuthSplash extends StatefulWidget {
  const _AuthSplash();

  @override
  State<_AuthSplash> createState() => _AuthSplashState();
}

class _AuthSplashState extends State<_AuthSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Marca pulsante de fondo.
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_pulse.value);
                return Opacity(
                  opacity: 0.08 + 0.10 * t,
                  child: M3EClip(
                    shape: M3EShape.heart,
                    child: SizedBox(
                      width: 96 + 8 * t,
                      height: 96 + 8 * t,
                      child: ColoredBox(color: scheme.primary),
                    ),
                  ),
                );
              },
            ),
            // Squircle con progress M3E.
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(28),
              ),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3.2,
                  strokeCap: StrokeCap.round,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}