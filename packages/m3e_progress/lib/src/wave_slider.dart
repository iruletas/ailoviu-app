import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:m3e_shapes/m3e_shapes.dart';

/// Slider con onda sinusoidal sobre el track activo.
///
/// A diferencia de [M3ELinearProgressWithThumb], el thumb se dibuja
/// dentro del mismo `Canvas` que la onda, así no hay gap entre track y
/// thumb cuando el thumb morph a pill vertical.
///
/// Cuando `isPlaying == false`, la amplitud de la onda se aplana a 0 y
/// el track activo se ve como una línea recta.
class WaveSlider extends StatefulWidget {
  final double progress;
  final bool isPlaying;
  final double trackHeight;
  final double thumbSize;
  final M3EShape thumbShape;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final double waveAmplitude;
  final double waveWavelength;
  final double waveSpeed;

  /// Callback con el progreso 0..1 cuando el usuario suelta el scrub.
  /// Si es null, el slider es solo visual.
  final ValueChanged<double>? onSeek;

  /// Callback opcional con el progreso intermedio 0..1 durante el
  /// arrastre. Útil para previews en vivo.
  final ValueChanged<double>? onScrub;

  const WaveSlider({
    super.key,
    required this.progress,
    this.isPlaying = true,
    this.trackHeight = 8.0,
    this.thumbSize = 16.0,
    this.thumbShape = M3EShape.circle,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.waveAmplitude = 5.0,
    this.waveWavelength = 40.0,
    this.waveSpeed = 1.0,
    this.onSeek,
    this.onScrub,
  });

  @override
  State<WaveSlider> createState() => _WaveSliderState();
}

class _WaveSliderState extends State<WaveSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  bool _dragging = false;
  double? _dragValue;
  int _lastHapticPercent = -1;

  double get _thumbWidthMultiplier => _dragging ? 1.4 : 1.0;
  double get _thumbHeightMultiplier => _dragging ? 2.0 : 1.0;

  double get _trackEdgePadding {
    final thumbWidth = widget.thumbSize * _thumbWidthMultiplier;
    final thumbHeight = widget.thumbSize * _thumbHeightMultiplier;
    return math.max(thumbWidth, thumbHeight) / 2.0;
  }

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _syncWaveAnimation();
  }

  @override
  void didUpdateWidget(covariant WaveSlider old) {
    super.didUpdateWidget(old);
    if (old.isPlaying != widget.isPlaying ||
        old.waveSpeed != widget.waveSpeed) {
      _syncWaveAnimation();
    }
  }

  void _syncWaveAnimation() {
    if (widget.isPlaying && widget.waveAmplitude > 0) {
      _waveController
        ..duration = Duration(
          milliseconds: (3000 / math.max(0.1, widget.waveSpeed)).round(),
        )
        ..repeat();
    } else {
      _waveController.stop();
      _waveController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    if (widget.onSeek == null) return;
    setState(() {
      _dragging = true;
      _lastHapticPercent = (widget.progress * 100).round();
    });
  }

  void _onDragUpdate(DragUpdateDetails d, Size size) {
    if (widget.onSeek == null) return;
    if (size.width <= 0.0) return;

    final localX = d.localPosition.dx - _trackEdgePadding;
    final usable = size.width - 2 * _trackEdgePadding;
    if (usable <= 0.0) return;

    final value = (localX / usable).clamp(0.0, 1.0);

    final percent = (value * 100).round();
    if (percent != _lastHapticPercent) {
      _lastHapticPercent = percent;
      HapticFeedback.selectionClick();
    }

    setState(() => _dragValue = value);
    widget.onScrub?.call(value);
  }

  void _onDragEnd(DragEndDetails d) {
    if (widget.onSeek == null) return;
    final value = _dragValue;
    setState(() {
      _dragging = false;
      _dragValue = null;
    });
    if (value != null) {
      widget.onSeek!(value);
    }
  }

  void _onTapDown(TapDownDetails d, Size size) {
    if (widget.onSeek == null) return;
    if (size.width <= 0.0) return;
    final localX = d.localPosition.dx - _trackEdgePadding;
    final usable = size.width - 2 * _trackEdgePadding;
    if (usable <= 0.0) return;
    final value = (localX / usable).clamp(0.0, 1.0);
    widget.onSeek!(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.activeColor ?? theme.colorScheme.primary;
    final inactive =
        widget.inactiveColor ?? theme.colorScheme.surfaceContainerHighest;
    final thumbColor = widget.thumbColor ?? theme.colorScheme.primary;

    final progress = (_dragValue ?? widget.progress).clamp(0.0, 1.0);
    final effectiveAmplitude = widget.isPlaying ? widget.waveAmplitude : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final thumbHeight = widget.thumbSize * _thumbHeightMultiplier;
        final totalHeight = math.max(
          widget.trackHeight + effectiveAmplitude * 2 + 4,
          thumbHeight,
        );
        final size = Size(totalWidth, totalHeight);

        return Semantics(
          slider: true,
          value: '${(progress * 100).round()}%',
          onIncrease: widget.onSeek != null
              ? () => widget.onSeek!((progress + 0.05).clamp(0.0, 1.0))
              : null,
          onDecrease: widget.onSeek != null
              ? () => widget.onSeek!((progress - 0.05).clamp(0.0, 1.0))
              : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _onTapDown(d, size),
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: (d) => _onDragUpdate(d, size),
            onHorizontalDragEnd: _onDragEnd,
            child: SizedBox(
              height: totalHeight,
              width: totalWidth,
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _WaveSliderPainter(
                      progress: progress,
                      trackHeight: widget.trackHeight,
                      thumbSize: widget.thumbSize,
                      thumbShape: widget.thumbShape,
                      thumbWidthMultiplier: _thumbWidthMultiplier,
                      thumbHeightMultiplier: _thumbHeightMultiplier,
                      trackEdgePadding: _trackEdgePadding,
                      activeColor: active,
                      inactiveColor: inactive,
                      thumbColor: thumbColor,
                      waveAmplitude: effectiveAmplitude,
                      waveWavelength: widget.waveWavelength,
                      wavePhase: _waveController.value * 2 * math.pi,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveSliderPainter extends CustomPainter {
  final double progress;
  final double trackHeight;
  final double thumbSize;
  final M3EShape thumbShape;
  final double thumbWidthMultiplier;
  final double thumbHeightMultiplier;
  final double trackEdgePadding;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbColor;
  final double waveAmplitude;
  final double waveWavelength;
  final double wavePhase;

  _WaveSliderPainter({
    required this.progress,
    required this.trackHeight,
    required this.thumbSize,
    required this.thumbShape,
    required this.thumbWidthMultiplier,
    required this.thumbHeightMultiplier,
    required this.trackEdgePadding,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbColor,
    required this.waveAmplitude,
    required this.waveWavelength,
    required this.wavePhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2.0;
    final trackLeft = trackEdgePadding;
    final trackRight = size.width - trackEdgePadding;
    final trackWidth = trackRight - trackLeft;
    if (trackWidth <= 0.0) return;

    final activeRight = trackLeft + trackWidth * progress;

    // 1. Track inactivo: rectángulo redondeado entre activeRight y trackRight.
    final inactiveRect = Rect.fromLTRB(
      activeRight,
      centerY - trackHeight / 2.0,
      trackRight,
      centerY + trackHeight / 2.0,
    );
    if (inactiveRect.width > 0.0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          inactiveRect,
          Radius.circular(trackHeight / 2.0),
        ),
        Paint()..color = inactiveColor,
      );
    }

    // 2. Track activo: onda sinusoidal sobre [trackLeft, activeRight].
    final activeWidth = activeRight - trackLeft;
    if (activeWidth > 0.0) {
      if (waveAmplitude <= 0.0) {
        // Sin onda: rectángulo plano.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              trackLeft,
              centerY - trackHeight / 2.0,
              activeRight,
              centerY + trackHeight / 2.0,
            ),
            Radius.circular(trackHeight / 2.0),
          ),
          Paint()..color = activeColor,
        );
      } else {
        final path = _buildWavePath(
          width: activeWidth,
          height: trackHeight,
          amplitude: waveAmplitude,
          wavelength: waveWavelength,
          phase: wavePhase,
          centerY: centerY,
        );
        canvas
          ..save()
          ..translate(trackLeft, 0)
          ..drawPath(path, Paint()..color = activeColor)
          ..restore();
      }
    }

    // 3. Thumb (morphing) en activeRight, centrado verticalmente.
    final thumbWidth = thumbSize * thumbWidthMultiplier;
    final thumbHeight = thumbSize * thumbHeightMultiplier;
    final thumbRect = Rect.fromCenter(
      center: Offset(activeRight, centerY),
      width: thumbWidth,
      height: thumbHeight,
    );

    canvas
      ..save()
      ..translate(thumbRect.left, thumbRect.top)
      ..clipPath(_thumbPath(thumbWidth, thumbHeight))
      ..drawRect(
        Rect.fromLTWH(0, 0, thumbWidth, thumbHeight),
        Paint()..color = thumbColor,
      )
      ..restore();

    // 4. Borde sutil del thumb para que se lea sobre el track activo.
    canvas.drawPath(
      _thumbPath(thumbWidth, thumbHeight).shift(thumbRect.topLeft),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = inactiveColor.withValues(alpha: 0.5),
    );
  }

  Path _buildWavePath({
    required double width,
    required double height,
    required double amplitude,
    required double wavelength,
    required double phase,
    required double centerY,
  }) {
    // La amplitud se limita para que no cruce el track.
    final a = math.min(amplitude, height / 2.0);
    final steps = math.max(2, (width / 3).ceil());
    final dx = width / steps;
    final period = math.max(8.0, wavelength);
    final k = 2 * math.pi / period;

    final path = Path();

    // Borde superior (de 0 a width), con sin(x*k + phase).
    path.moveTo(0, centerY - a - height / 2.0);
    for (int i = 1; i <= steps; i++) {
      final x = i * dx;
      final y = centerY - a - height / 2.0 + a * math.sin(k * x + phase);
      path.lineTo(x, y);
    }

    // Borde inferior (de width a 0), con sin(x*k + phase) reflejado.
    for (int i = steps; i >= 0; i--) {
      final x = i * dx;
      final y = centerY + a + height / 2.0 + a * math.sin(k * x + phase);
      path.lineTo(x, y);
    }

    path.close();
    return path;
  }

  Path _thumbPath(double width, double height) {
    return m3ePath(
      thumbShape,
      Size(width, height),
      keepAspect: false,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveSliderPainter old) =>
      old.progress != progress ||
      old.trackHeight != trackHeight ||
      old.thumbSize != thumbSize ||
      old.thumbShape != thumbShape ||
      old.thumbWidthMultiplier != thumbWidthMultiplier ||
      old.thumbHeightMultiplier != thumbHeightMultiplier ||
      old.trackEdgePadding != trackEdgePadding ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor ||
      old.thumbColor != thumbColor ||
      old.waveAmplitude != waveAmplitude ||
      old.waveWavelength != waveWavelength ||
      old.wavePhase != wavePhase;
}