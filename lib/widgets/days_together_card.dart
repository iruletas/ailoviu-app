import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_components.dart';

/// Tarjeta "Días juntos" para Hogar.
///
/// - Gradiente tonal suave entre primaryContainer y tertiaryContainer.
/// - Squircle con latido doble del corazón.
/// - Cifra de días grande (displayMedium, w900) cuando hay fecha.
/// - Pill chip con años/meses.
/// - Botón "Elegir fecha" cuando no hay fecha.
/// - Badge festivo si hoy es aniversario o un hito (100, 500, 1000).
/// - Compresión táctil con háptica.
class DaysTogetherCard extends StatefulWidget {
  final DateTime? startDate;
  final VoidCallback? onTap;

  const DaysTogetherCard({
    super.key,
    required this.startDate,
    this.onTap,
  });

  @override
  State<DaysTogetherCard> createState() => _DaysTogetherCardState();
}

class _DaysTogetherCardState extends State<DaysTogetherCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartbeatController;
  late final Animation<double> _heartbeat;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _heartbeat = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.05)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.20)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.20, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 35,
      ),
    ]).animate(_heartbeatController);
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    super.dispose();
  }

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    // Háptica diferenciada si hoy es aniversario.
    final isAnniversary = _isAnniversaryToday(widget.startDate);
    if (isAnniversary) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    widget.onTap!();
  }

  static bool _isAnniversaryToday(DateTime? start) {
    if (start == null) return false;
    final now = DateTime.now();
    return now.month == start.month && now.day == start.day;
  }

  static String? _celebrationBadge(DateTime? start) {
    if (start == null) return null;
    final now = DateTime.now();
    if (now.month == start.month && now.day == start.day) {
      return '🎉 ¡Hoy es el día!';
    }
    final days = now.difference(start).inDays;
    if (days == 100 || days == 500 || days == 1000 ||
        days == 1500 || days == 2000) {
      return '✨ ¡$days días!';
    }
    return null;
  }

  static String _formatChipLabel(DateTime start) {
    final now = DateTime.now();
    int years = now.year - start.year;
    int months = now.month - start.month;
    if (now.day < start.day) months--;
    if (months < 0) {
      years--;
      months += 12;
    }
    if (years > 0) {
      final yw = years == 1 ? 'año' : 'años';
      if (months > 0) {
        final mw = months == 1 ? 'mes' : 'meses';
        return '$years $yw y $months $mw juntos';
      }
      return '$years $yw juntos';
    }
    if (months > 0) {
      final mw = months == 1 ? 'mes' : 'meses';
      return '$months $mw juntos';
    }
    final days = now.difference(start).inDays;
    return '$days ${days == 1 ? "día" : "días"} juntos';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final start = widget.startDate;
    final celebration = _celebrationBadge(start);
    final isAnniversary = _isAnniversaryToday(start);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null ? null : _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  scheme.primaryContainer.withValues(alpha: 0.15),
                  scheme.surfaceContainerLow,
                ),
                Color.alphaBlend(
                  scheme.tertiaryContainer.withValues(alpha: 0.12),
                  scheme.surfaceContainerLow,
                ),
              ],
            ),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScaleTransition(
                    scale: _heartbeat,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isAnniversary
                            ? [
                                BoxShadow(
                                  color: scheme.primary.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 24,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (celebration != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        celebration,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1.0)
                          .animate(animation),
                      child: child,
                    ),
                  );
                },
                child: start == null
                    ? _EmptyDaysState(
                        key: const ValueKey('empty'),
                        onTap: widget.onTap,
                      )
                    : _ConfiguredDaysState(
                        key: ValueKey('filled-$start'),
                        start: start,
                        scheme: scheme,
                        theme: theme,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDaysState extends StatelessWidget {
  final VoidCallback? onTap;
  const _EmptyDaysState({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configura tu aniversario',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: onTap,
          icon: const Icon(Icons.calendar_today_rounded, size: 18),
          label: const Text('Elegir fecha'),
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
          ),
        ),
      ],
    );
  }
}

class _ConfiguredDaysState extends StatelessWidget {
  final DateTime start;
  final ColorScheme scheme;
  final ThemeData theme;

  const _ConfiguredDaysState({
    super.key,
    required this.start,
    required this.scheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final days = DateTime.now().difference(start).inDays;
    final chipLabel = _DaysTogetherCardState._formatChipLabel(start);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$days',
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: scheme.primary,
            height: 1.0,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            chipLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}