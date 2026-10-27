import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:m3e_shapes/m3e_shapes.dart';

/// Botón de play/pause con morphing real de forma.
class MorphingPlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback? onPressed;
  final double size;
  final M3EShape pauseShape;
  final M3EShape playShape;
  final Duration rotationPeriod;

  /// Si es `false`, el botón no rota cuando reproduce. Se usa en la
  /// isla colapsada (donde la rotación no se nota visualmente y
  /// consumiría CPU por nada durante el teclado u otras animaciones
  /// del sistema).
  final bool animateRotation;

  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool hapticsEnabled;

  const MorphingPlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.size = 64.0,
    this.pauseShape = M3EShape.circle,
    this.playShape = M3EShape.cookie9Sided,
    this.rotationPeriod = const Duration(seconds: 15),
    this.animateRotation = true,
    this.backgroundColor,
    this.foregroundColor,
    this.hapticsEnabled = true,
  });

  @override
  State<MorphingPlayPauseButton> createState() =>
      _MorphingPlayPauseButtonState();
}

class _MorphingPlayPauseButtonState extends State<MorphingPlayPauseButton>
    with TickerProviderStateMixin {
  late final AnimationController _morphController;
  late final AnimationController _rotationController;
  late final AnimationController _pressController;

  bool _isPressed = false;
  bool _isVisible = true;
  bool _tickersEnabled = true;

  @override
  void initState() {
    super.initState();

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: widget.isPlaying ? 1.0 : 0.0,
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: widget.rotationPeriod,
    );

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _syncRotation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickersEnabled = TickerMode.of(context);
    final route = ModalRoute.of(context);
    _isVisible = route == null || route.isCurrent;
    _syncRotation();
  }

  @override
  void didUpdateWidget(covariant MorphingPlayPauseButton old) {
    super.didUpdateWidget(old);

    if (old.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _morphController.forward();
      } else {
        _morphController.reverse();
      }
      _syncRotation();
    }

    if (old.rotationPeriod != widget.rotationPeriod) {
      _rotationController.duration = widget.rotationPeriod;
      _syncRotation();
    }

    if (old.animateRotation != widget.animateRotation) {
      _syncRotation();
    }
  }

  /// Solo rota si: isPlaying, el caller lo pidió (`animateRotation`),
  /// los tickers están habilitados, y la ruta que contiene el widget
  /// es la actual (no está tapada por un push).
  void _syncRotation() {
    final shouldRotate = widget.isPlaying &&
        widget.animateRotation &&
        _tickersEnabled &&
        _isVisible;
    if (shouldRotate) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    _rotationController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  void _onTap() {
    if (widget.onPressed == null) return;
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = widget.backgroundColor ?? theme.colorScheme.primary;
    final fg = widget.foregroundColor ?? theme.colorScheme.onPrimary;

    final scale = 1.0 - _pressController.value * 0.08;

    return Semantics(
      button: true,
      label: widget.isPlaying ? 'Pausar' : 'Reproducir',
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: _onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _morphController,
            _rotationController,
            _pressController,
          ]),
          builder: (context, _) {
            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: _rotationController.value * 2 * math.pi,
                      child: M3EMorphClip(
                        from: widget.pauseShape,
                        to: widget.playShape,
                        progress: _morphController.value,
                        child: _buildBackground(bg, theme),
                      ),
                    ),
                    _buildIcon(fg),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackground(Color color, ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            Color.lerp(
                  color,
                  theme.colorScheme.primaryContainer,
                  0.35,
                ) ??
                color,
          ],
        ),
      ),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
      ),
    );
  }

  Widget _buildIcon(Color fg) {
    final morphValue = _morphController.value;
    final iconSize = widget.size * 0.45;

    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: 1.0 - morphValue,
          child: Icon(
            Icons.play_arrow_rounded,
            size: iconSize,
            color: fg,
          ),
        ),
        Opacity(
          opacity: morphValue,
          child: Icon(
            Icons.pause_rounded,
            size: iconSize,
            color: fg,
          ),
        ),
      ],
    );
  }
}