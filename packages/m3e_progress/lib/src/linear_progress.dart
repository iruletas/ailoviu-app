import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:m3e_shapes/m3e_shapes.dart';

import 'linear_style.dart';
import 'wave_slider.dart';

/// Barra lineal de progreso, sin thumb interactivo.
class M3ELinearProgressBar extends StatelessWidget {
  final double progress;
  final LinearProgressStyle style;
  final bool isPlaying;
  final double trackHeight;
  final Color? activeColor;
  final Color? inactiveColor;
  final double waveAmplitude;
  final double waveWavelength;

  const M3ELinearProgressBar({
    super.key,
    required this.progress,
    this.style = LinearProgressStyle.rounded,
    this.isPlaying = true,
    this.trackHeight = 6.0,
    this.activeColor,
    this.inactiveColor,
    this.waveAmplitude = 4.0,
    this.waveWavelength = 32.0,
  });

  double get effectiveTrackHeight {
    switch (style) {
      case LinearProgressStyle.thin:
        return math.max(2.0, trackHeight * 0.4);
      case LinearProgressStyle.thick:
        return trackHeight * 1.6;
      default:
        return trackHeight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activeColor ?? theme.colorScheme.primary;
    final inactive =
        inactiveColor ?? theme.colorScheme.surfaceContainerHighest;

    if (style == LinearProgressStyle.wave) {
      return IgnorePointer(
        child: WaveSlider(
          progress: progress.clamp(0.0, 1.0),
          isPlaying: isPlaying,
          trackHeight: trackHeight,
          waveAmplitude: 6.0,
          activeColor: active,
          inactiveColor: inactive,
          thumbColor: active,
        ),
      );
    }

    Widget buildTrack(Animation<double>? glow) => _TrackPainter(
          progress: progress.clamp(0.0, 1.0),
          style: style,
          trackHeight: effectiveTrackHeight,
          activeColor: active,
          inactiveColor: inactive,
          waveAmplitude: isPlaying ? waveAmplitude : 0.0,
          waveWavelength: waveWavelength,
          glow: glow,
        );

    final Widget bar = style == LinearProgressStyle.glow
        ? _GlowBuilder(
            active: isPlaying,
            builder: (context, glow) => buildTrack(glow),
          )
        : buildTrack(null);

    final reserve = style == LinearProgressStyle.wavy ? waveAmplitude * 2.0 : 0.0;
    if (reserve <= 0.0) return bar;
    return SizedBox(
      height: effectiveTrackHeight + reserve,
      child: Center(child: bar),
    );
  }
}

/// Barra lineal con thumb arrastrable (scrub completo).
class M3ELinearProgressWithThumb extends StatefulWidget {
  final double progress;
  final LinearProgressStyle style;
  final bool isPlaying;
  final double trackHeight;
  final double thumbSize;
  final M3EShape thumbShape;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final double waveAmplitude;
  final double waveWavelength;
  final ValueChanged<double>? onSeek;
  final bool enabled;

  const M3ELinearProgressWithThumb({
    super.key,
    required this.progress,
    this.style = LinearProgressStyle.rounded,
    this.isPlaying = true,
    this.trackHeight = 6.0,
    this.thumbSize = 14.0,
    this.thumbShape = M3EShape.circle,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.waveAmplitude = 4.0,
    this.waveWavelength = 32.0,
    this.onSeek,
    this.enabled = true,
  });

  @override
  State<M3ELinearProgressWithThumb> createState() =>
      _M3ELinearProgressWithThumbState();
}

class _M3ELinearProgressWithThumbState
    extends State<M3ELinearProgressWithThumb> {
  bool _dragging = false;
  double? _dragValue;
  int _lastHapticPercent = -1;

  double get _effectiveTrackHeight {
    switch (widget.style) {
      case LinearProgressStyle.thin:
        return math.max(2.0, widget.trackHeight * 0.4);
      case LinearProgressStyle.thick:
        return widget.trackHeight * 1.6;
      default:
        return widget.trackHeight;
    }
  }

  double get _thumbWidthMultiplier => _dragging ? 1.4 : 1.0;
  double get _thumbHeightMultiplier => _dragging ? 2.0 : 1.0;

  double get _trackEdgePadding {
    final thumbWidth = widget.thumbSize * _thumbWidthMultiplier;
    final thumbHeight = widget.thumbSize * _thumbHeightMultiplier;
    return math.max(thumbWidth, thumbHeight) / 2.0;
  }

  void _onDragStart(DragStartDetails d) {
    if (!widget.enabled || widget.onSeek == null) return;
    setState(() {
      _dragging = true;
      _lastHapticPercent = (widget.progress * 100).round();
    });
  }

  void _onDragUpdate(DragUpdateDetails d, Size trackSize) {
    if (!widget.enabled || widget.onSeek == null) return;
    if (trackSize.width <= 0.0) return;

    final localX = d.localPosition.dx - _trackEdgePadding;
    final usable = trackSize.width - 2 * _trackEdgePadding;
    if (usable <= 0.0) return;

    final value = (localX / usable).clamp(0.0, 1.0);

    final percent = (value * 100).round();
    if (percent != _lastHapticPercent) {
      _lastHapticPercent = percent;
      HapticFeedback.selectionClick();
    }

    setState(() => _dragValue = value);
  }

  void _onDragEnd(DragEndDetails d) {
    if (!widget.enabled || widget.onSeek == null) return;
    final value = _dragValue;
    setState(() {
      _dragging = false;
      _dragValue = null;
    });
    if (value != null) {
      widget.onSeek!(value);
    }
  }

  void _onTapDown(TapDownDetails d, Size trackSize) {
    if (!widget.enabled || widget.onSeek == null) return;
    if (trackSize.width <= 0.0) return;
    final localX = d.localPosition.dx - _trackEdgePadding;
    final usable = trackSize.width - 2 * _trackEdgePadding;
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

    if (widget.style == LinearProgressStyle.wave) {
      return WaveSlider(
        progress: widget.progress.clamp(0.0, 1.0),
        isPlaying: widget.isPlaying,
        trackHeight: widget.trackHeight,
        thumbSize: widget.thumbSize,
        thumbShape: widget.thumbShape,
        activeColor: active,
        inactiveColor: inactive,
        thumbColor: thumbColor,
        waveAmplitude: 6.0,
        onSeek: widget.enabled ? widget.onSeek : null,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final thumbHeight = widget.thumbSize * _thumbHeightMultiplier;
        final totalHeight = math.max(
          _effectiveTrackHeight,
          thumbHeight,
        );

        final trackSize = Size(trackWidth, totalHeight);
        final maxAmplitude =
            math.max(0.0, (totalHeight - _effectiveTrackHeight) / 2.0);
        final amplitude = widget.isPlaying
            ? math.min(widget.waveAmplitude, maxAmplitude)
            : 0.0;

        Widget buildTrack(Animation<double>? glow) => _TrackPainter(
              progress: progress,
              style: widget.style,
              trackHeight: _effectiveTrackHeight,
              activeColor: active,
              inactiveColor: inactive,
              waveAmplitude: amplitude,
              waveWavelength: widget.waveWavelength,
              glow: glow,
            );

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
            onTapDown: (d) => _onTapDown(d, trackSize),
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: (d) => _onDragUpdate(d, trackSize),
            onHorizontalDragEnd: _onDragEnd,
            child: SizedBox(
              width: trackWidth,
              height: totalHeight,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _trackEdgePadding,
                    ),
                    child: widget.style == LinearProgressStyle.glow
                        ? _GlowBuilder(
                            active: widget.isPlaying,
                            builder: (context, glow) => buildTrack(glow),
                          )
                        : buildTrack(null),
                  ),
                  Positioned(
                    left: _trackEdgePadding +
                        (trackWidth - 2 * _trackEdgePadding) * progress -
                        (widget.thumbSize * _thumbWidthMultiplier) / 2.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      width: widget.thumbSize * _thumbWidthMultiplier,
                      height: widget.thumbSize * _thumbHeightMultiplier,
                      child: M3EClip(
                        shape: widget.thumbShape,
                        child: ColoredBox(color: thumbColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrackPainter extends StatelessWidget {
  final double progress;
  final LinearProgressStyle style;
  final double trackHeight;
  final Color activeColor;
  final Color inactiveColor;
  final double waveAmplitude;
  final double waveWavelength;
  final Animation<double>? glow;

  const _TrackPainter({
    required this.progress,
    required this.style,
    required this.trackHeight,
    required this.activeColor,
    required this.inactiveColor,
    required this.waveAmplitude,
    required this.waveWavelength,
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: trackHeight,
      child: CustomPaint(
        painter: _LinearTrackPainter(
          progress: progress,
          style: style,
          trackHeight: trackHeight,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          waveAmplitude: waveAmplitude,
          waveWavelength: waveWavelength,
          glow: glow,
        ),
      ),
    );
  }
}

class _LinearTrackPainter extends CustomPainter {
  final double progress;
  final LinearProgressStyle style;
  final double trackHeight;
  final Color activeColor;
  final Color inactiveColor;
  final double waveAmplitude;
  final double waveWavelength;
  final Animation<double>? glow;

  _LinearTrackPainter({
    required this.progress,
    required this.style,
    required this.trackHeight,
    required this.activeColor,
    required this.inactiveColor,
    required this.waveAmplitude,
    required this.waveWavelength,
    this.glow,
  }) : super(repaint: glow);

  @override
  void paint(Canvas canvas, Size size) {
    final inactivePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, trackHeight),
          Radius.circular(trackHeight / 2.0),
        ),
      );
    canvas.drawPath(inactivePath, Paint()..color = inactiveColor);

    final activeWidth = size.width * progress.clamp(0.0, 1.0);
    if (activeWidth <= 0.0 || trackHeight <= 0.0) return;

    if (style == LinearProgressStyle.wavy && waveAmplitude > 0.0) {
      _paintWavy(canvas, activeWidth);
      return;
    }

    if (style == LinearProgressStyle.glow) {
      _paintGlow(canvas, activeWidth);
      return;
    }

    final activePath = buildLinearTrackPath(
      style: style,
      progress: progress,
      trackWidth: size.width,
      trackHeight: trackHeight,
      waveAmplitude: waveAmplitude,
      waveWavelength: waveWavelength,
    );
    if (activePath.getBounds().isEmpty) return;

    if (style == LinearProgressStyle.gradient) {
      final shader = LinearGradient(
        colors: [_deepen(activeColor), activeColor],
      ).createShader(Rect.fromLTWH(0, 0, activeWidth, trackHeight));
      canvas.drawPath(activePath, Paint()..shader = shader);
    } else {
      canvas.drawPath(activePath, Paint()..color = activeColor);
    }
  }

  void _paintGlow(Canvas canvas, double activeWidth) {
    final half = trackHeight / 2.0;
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, activeWidth, trackHeight),
      Radius.circular(half),
    );
    canvas.drawRRect(bar, Paint()..color = activeColor);

    final cycle = glow?.value;
    if (cycle == null) return;

    const travelPortion = 0.72;
    final travelling = cycle < travelPortion;
    final u = travelling ? cycle / travelPortion : 1.0;
    final light = _lighten(activeColor);

    if (travelling) {
      final bandWidth = (activeWidth * 0.35).clamp(20.0, 72.0);
      final centerX = activeWidth * u * u;
      final intensity = 0.25 + 0.75 * u;
      final band = Rect.fromLTWH(
        centerX - bandWidth / 2.0,
        0,
        bandWidth,
        trackHeight,
      );
      canvas.save();
      canvas.clipRRect(bar);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            colors: [
              light.withValues(alpha: 0.0),
              light.withValues(alpha: 0.7 * intensity),
              light.withValues(alpha: 0.0),
            ],
          ).createShader(band),
      );
      canvas.restore();
    }

    final haloStrength = travelling
        ? u * u * u
        : 1.0 - (cycle - travelPortion) / (1.0 - travelPortion);
    if (haloStrength <= 0.0) return;

    final haloRadius = trackHeight * 1.5;
    final haloCenter = Offset(math.max(half, activeWidth - half), half);
    canvas.drawCircle(
      haloCenter,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            light.withValues(alpha: 0.65 * haloStrength),
            light.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: haloCenter, radius: haloRadius),
        ),
    );
  }

  void _paintWavy(Canvas canvas, double activeWidth) {
    final half = trackHeight / 2.0;
    final startX = half;
    final endX = activeWidth - half;

    if (endX <= startX) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, activeWidth, trackHeight),
          Radius.circular(half),
        ),
        Paint()..color = activeColor,
      );
      return;
    }

    final path = buildWavyCenterline(
      startX: startX,
      endX: endX,
      centerY: half,
      amplitude: waveAmplitude,
      wavelength: waveWavelength,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackHeight
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = activeColor,
    );
  }

  @override
  bool shouldRepaint(covariant _LinearTrackPainter old) =>
      old.progress != progress ||
      old.style != style ||
      old.trackHeight != trackHeight ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor ||
      old.waveAmplitude != waveAmplitude ||
      old.waveWavelength != waveWavelength ||
      old.glow != glow;
}

Color _deepen(Color color, [double amount = 0.18]) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .toColor();
}

Color _lighten(Color color, [double amount = 0.75]) {
  return Color.lerp(color, Colors.white, amount) ?? color;
}

class _GlowBuilder extends StatefulWidget {
  final bool active;
  final Widget Function(BuildContext context, Animation<double>? glow) builder;

  const _GlowBuilder({required this.active, required this.builder});

  @override
  State<_GlowBuilder> createState() => _GlowBuilderState();
}

class _GlowBuilderState extends State<_GlowBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _GlowBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: widget.builder(context, widget.active ? _controller : null),
    );
  }
}