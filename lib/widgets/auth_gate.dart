import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_shapes/m3e_shapes.dart';

import '../models/auth_models.dart';
import '../providers/auth_settings_providers.dart';
import '../screens/lock_screen.dart';

/// Duración mínima del splash cuando hay app-lock. Da tiempo a que
/// plugins nativos (Geolocator, Firebase, etc.) se enganchen al
/// `Activity` antes de que el contenido real se monte y dispare sus
/// efectos de arranque (p. ej. `LocationBootstrap`).
const Duration _kSplashMinDuration = Duration(seconds: 2);

/// Envuelve la app con el gate de app-lock.
///
/// - `loaded == false` → splash mínimo.
/// - `appLockEnabled == false` → deja pasar directo (sin splash
///   forzado).
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

  /// `true` cuando ya pasó [_kSplashMinDuration] desde el primer
  /// frame. Solo relevante si hay app-lock.
  bool _splashElapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Arranca el timer del splash mínimo en el primer frame. No
    // bloquea; solo marca un flag.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(_kSplashMinDuration, () {
        if (mounted) setState(() => _splashElapsed = true);
      });
    });
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

  /// `true` si hay que mostrar el splash para no exponer el
  /// contenido real antes de tiempo.
  bool _mustShowSplash(AppAuthSettings auth) {
    if (!auth.loaded) return true;
    // Con app-lock activo, forzamos un mínimo de splash para que
    // plugins nativos terminen de inicializar antes de montar el
    // árbol completo.
    if (auth.appLockEnabled && !_splashElapsed) return true;
    return false;
  }

  String _contentKey(AppAuthSettings auth, AuthSession session) {
    if (_mustShowSplash(auth)) return 'splash';
    if (!auth.appLockEnabled) return 'app';
    if (!session.appUnlocked) return 'lock';
    return 'app';
  }

  Widget _contentFor(AppAuthSettings auth, AuthSession session) {
    if (_mustShowSplash(auth)) return const _AuthSplash();
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

/// Splash de arranque: corazón M3E con latido orgánico sobre un
/// gradiente radial.
class _AuthSplash extends StatefulWidget {
  const _AuthSplash();

  @override
  State<_AuthSplash> createState() => _AuthSplashState();
}

class _AuthSplashState extends State<_AuthSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heartbeat;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _heartbeat = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.05)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubicEmphasized)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 35,
      ),
    ]).animate(_controller);

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.8,
            colors: [
              scheme.surfaceContainerLow,
              scheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _heartbeat,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.2),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: M3EClip(
                    shape: M3EShape.heart,
                    child: ColoredBox(
                      color: scheme.primaryContainer,
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 44,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _textFade,
                child: Text(
                  'Ailoviu',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}