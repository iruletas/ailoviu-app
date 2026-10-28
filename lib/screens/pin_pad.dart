import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Teclado numérico para PIN, con feedback expresivo.
///
/// - Dots que escalan al llenar (`backOut`).
/// - Shake horizontal al fallar la validación.
/// - Backspace reactivo (atenuado cuando vacío, ícono relleno al pulsar).
/// - Busy state: dots atenuados mientras `onCompleted` está pendiente.
/// - Háptica progresiva: light por dígito, medium al completar.
class PinPad extends StatefulWidget {
  final int length;
  final Future<bool> Function(String pin) onCompleted;
  final String? helperText;

  const PinPad({
    super.key,
    this.length = 4,
    required this.onCompleted,
    this.helperText,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _busy = false;
  bool _error = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _onDigit(String digit) async {
    if (_busy || _pin.length >= widget.length) return;
    final isLast = _pin.length == widget.length - 1;
    if (isLast) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _error = false;
      _pin += digit;
    });
    if (_pin.length == widget.length) {
      await _submit();
    }
  }

  Future<void> _onBackspace() async {
    if (_busy || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = false;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final ok = await widget.onCompleted(_pin);
    if (!mounted) return;
    if (!ok) {
      HapticFeedback.heavyImpact();
      await _shakeController.forward(from: 0);
      if (!mounted) return;
      setState(() {
        _error = true;
        _busy = false;
        _pin = '';
      });
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.helperText != null) ...[
          _HelperCapsule(text: widget.helperText!),
          const SizedBox(height: 20),
        ],
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(_shake.value, 0),
            child: child,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < widget.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                _PinDot(
                  filled: i < _pin.length,
                  error: _error,
                  busy: _busy,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 36),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'backspace'],
        ]) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final key in row) ...[
                _PinKey(
                  label: key,
                  enabled: !_busy,
                  isBackspaceActive: key == 'backspace' && _pin.isNotEmpty,
                  onTap: key == 'backspace'
                      ? (_pin.isEmpty || _busy ? null : _onBackspace)
                      : (key.isEmpty || _busy
                          ? null
                          : () => _onDigit(key)),
                ),
                const SizedBox(width: 16),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HelperCapsule extends StatelessWidget {
  final String text;

  const _HelperCapsule({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PinDot extends StatefulWidget {
  final bool filled;
  final bool error;
  final bool busy;

  const _PinDot({
    required this.filled,
    required this.error,
    required this.busy,
  });

  @override
  State<_PinDot> createState() => _PinDotState();
}

class _PinDotState extends State<_PinDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fillController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: widget.filled ? 1.0 : 0.0,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 50),
      TweenSequenceItem(
        tween: Tween(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.backOut)),
        weight: 50,
      ),
    ]).animate(_fillController);
  }

  @override
  void didUpdateWidget(covariant _PinDot old) {
    super.didUpdateWidget(old);
    if (old.filled != widget.filled) {
      if (widget.filled) {
        _fillController.forward(from: 0);
      } else {
        _fillController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final fillColor = widget.error
        ? scheme.error
        : (widget.filled ? scheme.primary : Colors.transparent);
    final borderColor = widget.error
        ? scheme.error
        : (widget.filled ? scheme.primary : scheme.outlineVariant);

    return AnimatedBuilder(
      animation: _scale,
      builder: (context, _) {
        final baseScale = widget.filled ? _scale.value : 1.0;
        final busyScale = widget.busy ? 0.9 : 1.0;
        return Transform.scale(
          scale: baseScale * busyScale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fillColor,
              border: Border.all(color: borderColor, width: 2),
            ),
          ),
        );
      },
    );
  }
}

class _PinKey extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isBackspaceActive;

  const _PinKey({
    required this.label,
    this.onTap,
    this.enabled = true,
    this.isBackspaceActive = false,
  });

  @override
  State<_PinKey> createState() => _PinKeyState();
}

class _PinKeyState extends State<_PinKey> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (widget.label.isEmpty) {
      return const SizedBox(width: 76, height: 76);
    }

    final isBackspace = widget.label == 'backspace';
    final disabled = widget.onTap == null;

    // Backspace: opacidad 35% cuando el PIN está vacío.
    final opacity = isBackspace && !widget.isBackspaceActive ? 0.35 : 1.0;

    final background = isBackspace
        ? scheme.surfaceContainerHighest
        : scheme.surfaceContainerLow;

    return AnimatedOpacity(
      opacity: disabled ? (isBackspace && !widget.isBackspaceActive ? 0.35 : 0.6) : opacity,
      duration: const Duration(milliseconds: 180),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: disabled ? null : (_) => _setPressed(true),
        onTapUp: disabled ? null : (_) => _setPressed(false),
        onTapCancel: disabled ? null : () => _setPressed(false),
        onTap: disabled ? null : widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _pressed
                  ? (isBackspace
                      ? scheme.tertiaryContainer
                      : scheme.secondaryContainer)
                  : background,
              borderRadius: BorderRadius.circular(28),
            ),
            child: isBackspace
                ? Icon(
                    _pressed
                        ? Icons.backspace_rounded
                        : Icons.backspace_outlined,
                    size: 24,
                    color: scheme.onSurfaceVariant,
                  )
                : Text(
                    widget.label,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}