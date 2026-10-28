import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_shapes/m3e_shapes.dart';

import '../providers/auth_settings_providers.dart';
import '../services/auth_service.dart';
import '../widgets/tonal_back_button.dart';
import 'pin_pad.dart';

/// Pantalla de creación de PIN fallback.
///
/// Flujo:
/// 1. `create`: pide un PIN de 4 dígitos.
/// 2. `confirm`: pide el mismo PIN otra vez.
/// 3. Si coincide → guarda hash, marca el flag, hace pop con `true`.
/// 4. Si no coincide → error banner + vuelve al paso `create`.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String? _firstPin;
  String? _errorText;
  bool _saving = false;
  bool _success = false;

  Future<bool> _onCreate(String pin) async {
    setState(() {
      _firstPin = pin;
      _errorText = null;
    });
    return true;
  }

  Future<bool> _onConfirm(String pin) async {
    if (_firstPin == null) return false;
    if (pin != _firstPin) {
      setState(() {
        _firstPin = null;
        _errorText = 'Los PIN no coinciden. Intenta de nuevo.';
      });
      return false;
    }
    setState(() => _saving = true);
    try {
      final service = await ref.read(authServiceProvider.future);
      await service.setAppPin(pin);
      await ref
          .read(authSettingsProvider.notifier)
          .markAppPinConfigured(true);
      if (!mounted) return true;
      HapticFeedback.heavyImpact();
      setState(() {
        _saving = false;
        _success = true;
      });
      // Pequeña pausa para que se vea el check antes de salir.
      await Future<void>.delayed(const Duration(milliseconds: 380));
      if (!mounted) return true;
      Navigator.of(context).pop(true);
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _firstPin = null;
          _errorText = 'No se pudo guardar el PIN. Intenta de nuevo.';
        });
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final step = _firstPin == null ? 'create' : 'confirm';

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar.large(
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: TonalBackButton(
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            title: Text(
              'Crear PIN',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _StepBadge(step: step),
                const SizedBox(height: 20),
                _StepHero(step: step, success: _success),
                const SizedBox(height: 24),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
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
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(curved),
                          child: child,
                        ),
                      );
                    },
                    child: _StepBody(
                      key: ValueKey(step),
                      step: step,
                      errorText: _errorText,
                      saving: _saving,
                      success: _success,
                      onCompleted:
                          step == 'create' ? _onCreate : _onConfirm,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  final String step;

  const _StepBadge({required this.step});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCreate = step == 'create';
    final bg = isCreate
        ? scheme.primaryContainer
        : scheme.tertiaryContainer;
    final fg = isCreate
        ? scheme.onPrimaryContainer
        : scheme.onTertiaryContainer;
    final label = isCreate ? '1 de 2 · Elige tu PIN' : '2 de 2 · Confirma tu PIN';
    final icon = isCreate ? Icons.pin_outlined : Icons.password_rounded;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.backOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepHero extends StatelessWidget {
  final String step;
  final bool success;

  const _StepHero({required this.step, required this.success});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCreate = step == 'create';

    final bg = success
        ? scheme.primaryContainer
        : (isCreate
            ? scheme.primaryContainer
            : scheme.tertiaryContainer);
    final fg = success
        ? scheme.onPrimaryContainer
        : (isCreate
            ? scheme.onPrimaryContainer
            : scheme.onTertiaryContainer);
    final icon = success
        ? Icons.check_rounded
        : (isCreate ? Icons.lock_open_rounded : Icons.lock_rounded);

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: success ? 88 : 72,
        height: success ? 88 : 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          boxShadow: success
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: Icon(
            icon,
            key: ValueKey('$step-$success'),
            size: success ? 44 : 32,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  final String step;
  final String? errorText;
  final bool saving;
  final bool success;
  final Future<bool> Function(String pin) onCompleted;

  const _StepBody({
    super.key,
    required this.step,
    required this.errorText,
    required this.saving,
    required this.success,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          step == 'create'
              ? 'Elige un PIN de 4 dígitos para desbloquear la app cuando el sistema no pueda hacerlo.'
              : 'Confirma el PIN que acabas de elegir.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: errorText == null
              ? const SizedBox(width: double.infinity)
              : _ErrorBanner(text: errorText!),
        ),
        const SizedBox(height: 24),
        if (saving || success)
          _SavingIndicator(success: success)
        else
          PinPad(
            key: ValueKey('pinpad-$step'),
            length: 4,
            onCompleted: onCompleted,
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;

  const _ErrorBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingIndicator extends StatelessWidget {
  final bool success;

  const _SavingIndicator({required this.success});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: success
                ? Icon(
                    Icons.check_circle_rounded,
                    key: const ValueKey('ok'),
                    size: 56,
                    color: scheme.primary,
                  )
                : SizedBox(
                    key: const ValueKey('loading'),
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                      color: scheme.primary,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            success ? 'PIN guardado' : 'Guardando…',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}