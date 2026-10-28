import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_settings_providers.dart';
import '../services/auth_service.dart';
import 'pin_pad.dart';
import 'pin_setup_screen.dart';

enum _LockMode { system, pin, unavailable, error }

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  _LockMode _mode = _LockMode.system;
  bool _busy = false;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trySystemAuth());
  }

  Future<void> _trySystemAuth() async {
    if (_busy || _unlocking) return;
    setState(() => _busy = true);

    final auth = ref.read(authSettingsProvider);
    if (!auth.systemAuthAvailable) {
      setState(() {
        _busy = false;
        _mode = auth.appPinFallbackConfigured
            ? _LockMode.pin
            : _LockMode.unavailable;
      });
      return;
    }

    final service = await ref.read(authServiceProvider.future);
    final result = await service.authenticateWithSystem();
    if (!mounted) return;

    switch (result) {
      case AuthResult.success:
        await _showUnlockBurst();
        break;
      case AuthResult.cancelled:
        setState(() => _busy = false);
        break;
      case AuthResult.notAvailable:
        final a = ref.read(authSettingsProvider);
        setState(() {
          _busy = false;
          _mode = a.appPinFallbackConfigured
              ? _LockMode.pin
              : _LockMode.unavailable;
        });
        break;
      case AuthResult.lockedOut:
      case AuthResult.error:
        setState(() {
          _busy = false;
          _mode = _LockMode.error;
        });
        break;
    }
  }

  /// Micro-burst antes de desbloquear: el ícono cambia a "lock_open"
  /// y se expande durante ~300ms. Comunica éxito antes de salir.
  Future<void> _showUnlockBurst() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = false;
      _unlocking = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    ref.read(authSessionProvider.notifier).unlockApp();
  }

  Future<bool> _onPin(String pin) async {
    final service = await ref.read(authServiceProvider.future);
    final ok = await service.verifyAppPin(pin);
    if (ok && mounted) {
      await _showUnlockBurst();
    }
    return ok;
  }

  Future<void> _openPinSetup() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
    if (created == true && mounted) {
      setState(() => _mode = _LockMode.pin);
    }
  }

  void _switchToPin() {
    HapticFeedback.selectionClick();
    setState(() => _mode = _LockMode.pin);
  }

  void _switchToSystem() {
    HapticFeedback.selectionClick();
    setState(() => _mode = _LockMode.system);
    WidgetsBinding.instance.addPostFrameCallback((_) => _trySystemAuth());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(36),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HeroLockIcon(mode: _mode, unlocking: _unlocking),
                    const SizedBox(height: 20),
                    Text(
                      _unlocking ? 'Desbloqueada' : 'Ailoviu está bloqueada',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        _subtitleForMode(),
                        key: ValueKey('${_mode}_$_busy'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeInOutCubicEmphasized,
                        switchOutCurve: Curves.easeInOutCubicEmphasized,
                        transitionBuilder: (child, animation) {
                          final curved = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOutCubicEmphasized,
                          );
                          return FadeTransition(
                            opacity: curved,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.04),
                                end: Offset.zero,
                              ).animate(curved),
                              child: child,
                            ),
                          );
                        },
                        child: _buildActionForMode(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleForMode() {
    if (_unlocking) return 'Entrando…';
    switch (_mode) {
      case _LockMode.system:
        return _busy
            ? 'Esperando autenticación…'
            : 'Autentícate para continuar.';
      case _LockMode.pin:
        return 'Ingresa tu PIN para continuar.';
      case _LockMode.unavailable:
        return 'No hay un método de desbloqueo disponible. Configura un PIN.';
      case _LockMode.error:
        return 'No se pudo autenticar. Intenta de nuevo.';
    }
  }

  Widget _buildActionForMode() {
    switch (_mode) {
      case _LockMode.system:
        if (_busy) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: SizedBox(
              key: ValueKey('busy-system'),
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3.2,
                strokeCap: StrokeCap.round,
              ),
            ),
          );
        }
        return Column(
          key: const ValueKey('action-system'),
          children: [
            _BiometricButton(onPressed: _trySystemAuth),
            const SizedBox(height: 12),
            if (ref.read(authSettingsProvider).appPinFallbackConfigured)
              TextButton(
                onPressed: _switchToPin,
                child: const Text('Usar PIN'),
              ),
          ],
        );
      case _LockMode.pin:
        final auth = ref.read(authSettingsProvider);
        return Column(
          key: const ValueKey('action-pin'),
          children: [
            PinPad(length: 4, onCompleted: _onPin),
            if (auth.systemAuthAvailable) ...[
              const SizedBox(height: 16),
              _SwitchMethodChip(
                icon: Icons.fingerprint_rounded,
                label: 'Usar huella o rostro',
                onTap: _switchToSystem,
              ),
            ],
          ],
        );
      case _LockMode.unavailable:
        return Column(
          key: const ValueKey('action-unavailable'),
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: _openPinSetup,
              icon: const Icon(Icons.pin_outlined),
              label: const Text('Configurar PIN'),
            ),
          ],
        );
      case _LockMode.error:
        final auth = ref.read(authSettingsProvider);
        return Container(
          key: const ValueKey('action-error'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer
                .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: _trySystemAuth,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  if (auth.appPinFallbackConfigured) {
                    _switchToPin();
                  } else {
                    _openPinSetup();
                  }
                },
                child: Text(
                  auth.appPinFallbackConfigured ? 'Usar PIN' : 'Configurar PIN',
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _HeroLockIcon extends StatelessWidget {
  final _LockMode mode;
  final bool unlocking;

  const _HeroLockIcon({required this.mode, required this.unlocking});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (bg, fg, icon) = switch ((mode, unlocking)) {
      (_, true) => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          Icons.lock_open_rounded,
        ),
      (_LockMode.system, _) => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          Icons.fingerprint_rounded,
        ),
      (_LockMode.pin, _) => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          Icons.pin_rounded,
        ),
      (_LockMode.unavailable, _) => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.key_rounded,
        ),
      (_LockMode.error, _) => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.error_outline_rounded,
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      width: unlocking ? 104 : 88,
      height: unlocking ? 104 : 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(32),
        boxShadow: unlocking
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          icon,
          key: ValueKey('$icon-$unlocking'),
          size: unlocking ? 52 : 40,
          color: fg,
        ),
      ),
    );
  }
}

class _BiometricButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _BiometricButton({required this.onPressed});

  @override
  State<_BiometricButton> createState() => _BiometricButtonState();
}

class _BiometricButtonState extends State<_BiometricButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          onPressed: _handleTap,
          icon: const Icon(Icons.fingerprint_rounded),
          label: const Text('Desbloquear'),
        ),
      ),
    );
  }
}

class _SwitchMethodChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SwitchMethodChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_SwitchMethodChip> createState() => _SwitchMethodChipState();
}

class _SwitchMethodChipState extends State<_SwitchMethodChip> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}