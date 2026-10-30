import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/home_models.dart';
import '../providers/home_providers.dart';

/// Botón de zumbido para Hogar.
///
/// - Squircle 52x52 con spring scale al toque.
/// - Anillo de cooldown con caps redondeados.
/// - Jitter shake del ícono al enviar.
/// - Badge flotante con zumbidos restantes del día.
/// - Toast flotante de cristal que aparece **a la derecha** del
///   botón (no encima, no centrado: no colisiona con nada).
/// - Háptica: lightImpact bloqueado, heavyImpact al enviar.
class BuzzButton extends ConsumerStatefulWidget {
  const BuzzButton({super.key});

  @override
  ConsumerState<BuzzButton> createState() => _BuzzButtonState();
}

class _BuzzButtonState extends ConsumerState<BuzzButton>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final AnimationController _jitterController;
  late final AnimationController _cooldownController;

  Timer? _toastTimer;
  bool _showToast = false;
  String _toastText = '';
  IconData _toastIcon = Icons.bolt_rounded;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _jitterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _cooldownController = AnimationController(
      vsync: this,
      duration: BuzzState.cooldown,
    )..addStatusListener(_onCooldownStatus);
    _syncCooldown();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _pressController.dispose();
    _jitterController.dispose();
    _cooldownController.dispose();
    super.dispose();
  }

  void _onCooldownStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {});
    }
  }

  void _syncCooldown() {
    final buzz = ref.read(buzzProvider);
    final cooldown = buzz.remainingCooldown();
    if (cooldown != null) {
      _cooldownController.value =
          1.0 - (cooldown.inMilliseconds / BuzzState.cooldown.inMilliseconds);
      _cooldownController.forward();
    } else {
      _cooldownController.reset();
    }
  }

  Future<void> _onTap() async {
    final buzz = ref.read(buzzProvider);
    final canBuzz = buzz.canBuzz();
    final cooldown = buzz.remainingCooldown();

    if (!canBuzz) {
      HapticFeedback.lightImpact();
      _showToastMessage(
        cooldown != null
            ? 'Espera ${cooldown.inSeconds}s para zumbar'
            : 'Límite diario alcanzado',
        Icons.timer_rounded,
      );
      return;
    }

    _pressController.forward().then((_) => _pressController.reverse());
    await _jitterController.forward(from: 0);
    HapticFeedback.heavyImpact();

    final sent = await ref.read(buzzProvider.notifier).tryBuzz();
    if (!mounted) return;

    if (sent) {
      _showToastMessage('¡Zumbido enviado! ⚡', Icons.bolt_rounded);
      _cooldownController.forward(from: 0);
    }
    setState(() {});
  }

  void _showToastMessage(String text, IconData icon) {
    _toastTimer?.cancel();
    setState(() {
      _toastText = text;
      _toastIcon = icon;
      _showToast = true;
    });
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _showToast = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final buzz = ref.watch(buzzProvider);
    final scheme = Theme.of(context).colorScheme;

    final canBuzz = buzz.canBuzz();
    final remaining = buzz.remainingToday();
    final cooldown = buzz.remainingCooldown();
    final lowLimit = remaining <= 5;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // ── Botón principal (hit target = 56×56, cubre el anillo) ──
        AnimatedBuilder(
          animation: Listenable.merge([
            _pressController,
            _jitterController,
            _cooldownController,
          ]),
          builder: (context, _) {
            final pressScale = 1.0 - _pressController.value * 0.12;
            final jitterX = _jitterController.isAnimating
                ? math.sin(_jitterController.value * math.pi * 6) * 2.5
                : 0.0;

            return Transform.translate(
              offset: Offset(jitterX, 0),
              child: Transform.scale(
                scale: pressScale,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onTap,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (cooldown != null)
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: CircularProgressIndicator(
                              value: _cooldownController.value,
                              strokeWidth: 2.5,
                              strokeCap: StrokeCap.round,
                              color: scheme.primary,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: canBuzz
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: canBuzz
                                ? [
                                    BoxShadow(
                                      color: scheme.primary
                                          .withValues(alpha: 0.35),
                                      blurRadius: 14,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.vibration_rounded,
                              size: 22,
                              color: canBuzz
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // ── Badge con restantes ────────────────────────────────────
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: lowLimit
                  ? scheme.errorContainer
                  : scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.surface, width: 2),
            ),
            child: Text(
              remaining <= 0 ? '0' : '$remaining',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: lowLimit
                    ? scheme.onErrorContainer
                    : scheme.onTertiaryContainer,
              ),
            ),
          ),
        ),

        // ── Toast a la DERECHA del botón ───────────────────────────
        if (_showToast)
          Positioned(
            left: 60,
            top: 0,
            bottom: 0,
            child: Center(
              child: _FloatingToast(
                text: _toastText,
                icon: _toastIcon,
              ),
            ),
          ),
      ],
    );
  }
}

class _FloatingToast extends StatelessWidget {
  final String text;
  final IconData icon;

  const _FloatingToast({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(-8 * (1 - value), 0),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}