import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:m3e_shapes/m3e_shapes.dart';

/// Los 8 estilos visuales de barra circular (270°).
///
/// Mismos nombres que [LinearProgressStyle] para que el usuario elija
/// un solo estilo y se aplique a ambas barras.
enum ArcProgressStyle {
  normal,
  wavy,
  rounded,
  thin,
  thick,
  gradient,
  segmented,
  dots,
}

extension ArcProgressStyleLabel on ArcProgressStyle {
  String get label {
    switch (this) {
      case ArcProgressStyle.normal:
        return 'Normal';
      case ArcProgressStyle.wavy:
        return 'Onda';
      case ArcProgressStyle.rounded:
        return 'Redondeada';
      case ArcProgressStyle.thin:
        return 'Delgada';
      case ArcProgressStyle.thick:
        return 'Gruesa';
      case ArcProgressStyle.gradient:
        return 'Gradiente';
      case ArcProgressStyle.segmented:
        return 'Segmentada';
      case ArcProgressStyle.dots:
        return 'Puntos';
    }
  }

  String get key => name;

  static ArcProgressStyle fromKey(String? key) {
    if (key == null || key.isEmpty) return ArcProgressStyle.wavy;
    for (final s in ArcProgressStyle.values) {
      if (s.name == key) return s;
    }
    return ArcProgressStyle.wavy;
  }
}

/// Barra de progreso circular de 270° con 8 estilos.
///
/// El arco va de `startAngle = 135°` a `135° + 270° = 405° = 45°`
/// (abierto por abajo).
class ArcWaveProgressBar extends StatefulWidget {
  final double progress;
  final bool isPlaying;
  final double size;
  final double strokeWidth;
  final double thumbSize;
  final M3EShape thumbShape;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final double waveAmplitude;
  final int waveSegments;
  final double startAngleDegrees;
  final double sweepAngleDegrees;
  final ArcProgressStyle style;
  final bool showThumb;
  final ValueChanged<double>? onSeek;
  final ValueChanged<double>? onScrub;

  const ArcWaveProgressBar({
    super.key,
    required this.progress,
    this.isPlaying = true,
    this.size = 120.0,
    this.strokeWidth = 8.0,
    this.thumbSize = 16.0,
    this.thumbShape = M3EShape.circle,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.waveAmplitude = 4.0,
    this.waveSegments = 64,
    this.startAngleDegrees = 135.0,
    this.sweepAngleDegrees = 270.0,
    this.style = ArcProgressStyle.wavy,
    this.showThumb = true,
    this.onSeek,
    this.onScrub,
  });

  @override
  State<ArcWaveProgressBar> createState() => _ArcWaveProgressBarState();
}

class _ArcWaveProgressBarState extends State<ArcWaveProgressBar> {
  bool _dragging = false;
  double? _dragValue;
  int _lastHapticPercent = -1;

  double get _thumbWidthMultiplier => _dragging ? 1.4 : 1.0;
  double get _thumbHeightMultiplier => _dragging ? 2.0 : 1.0;

  double get _startRad => widget.startAngleDegrees * math.pi / 180.0;
  double get _sweepRad => widget.sweepAngleDegrees * math.pi / 180.0;

  bool get _showWave => widget.style == ArcProgressStyle.wavy;

  double get _effectiveStrokeWidth {
    switch (widget.style) {
      case ArcProgressStyle.thin:
        return math.max(2.0, widget.strokeWidth - 2.0);
      case ArcProgressStyle.thick:
        return widget.strokeWidth + 2.0;
      default:
        return widget.strokeWidth;
    }
  }

  double _mapTouchToValue(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    var angle = math.atan2(dy, dx);
    if (angle < 0) angle += 2 * math.pi;

    var relative = angle - _startRad;
    if (relative < 0) relative += 2 * math.pi;

    if (relative > _sweepRad) {
      final distanceToStart = math.min(
        relative.abs(),
        (2 * math.pi - relative).abs(),
      );
      final distanceToEnd = math.min(
        (relative - _sweepRad).abs(),
        (2 * math.pi - (relative - _sweepRad)).abs(),
      );
      return distanceToStart < distanceToEnd ? 0.0 : 1.0;
    }

    return (relative / _sweepRad).clamp(0.0, 1.0);
  }

  void _onDragStart(DragStartDetails d) {
    if (widget.onSeek == null) return;
    setState(() {
      _dragging = true;
      _lastHapticPercent = (widget.progress * 100).round();
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (widget.onSeek == null) return;
    final value = _mapTouchToValue(d.localPosition);
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

  void _onTapDown(TapDownDetails d) {
    if (widget.onSeek == null) return;
    final value = _mapTouchToValue(d.localPosition);
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
    final effectiveAmplitude =
        widget.isPlaying && _showWave ? widget.waveAmplitude : 0.0;

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
        onTapDown: _onTapDown,
        onPanStart: _onDragStart,
        onPanUpdate: _onDragUpdate,
        onPanEnd: _onDragEnd,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _ArcWavePainter(
              progress: progress,
              size: widget.size,
              strokeWidth: _effectiveStrokeWidth,
              thumbSize: widget.thumbSize,
              thumbShape: widget.thumbShape,
              thumbWidthMultiplier: _thumbWidthMultiplier,
              thumbHeightMultiplier: _thumbHeightMultiplier,
              activeColor: active,
              inactiveColor: inactive,
              thumbColor: thumbColor,
              waveAmplitude: effectiveAmplitude,
              waveSegments: widget.waveSegments,
              startRad: _startRad,
              sweepRad: _sweepRad,
              style: widget.style,
              showThumb: widget.showThumb,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcWavePainter extends CustomPainter {
  final double progress;
  final double size;
  final double strokeWidth;
  final double thumbSize;
  final M3EShape thumbShape;
  final double thumbWidthMultiplier;
  final double thumbHeightMultiplier;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbColor;
  final double waveAmplitude;
  final int waveSegments;
  final double startRad;
  final double sweepRad;
  final ArcProgressStyle style;
  final bool showThumb;

  _ArcWavePainter({
    required this.progress,
    required this.size,
    required this.strokeWidth,
    required this.thumbSize,
    required this.thumbShape,
    required this.thumbWidthMultiplier,
    required this.thumbHeightMultiplier,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbColor,
    required this.waveAmplitude,
    required this.waveSegments,
    required this.startRad,
    required this.sweepRad,
    required this.style,
    required this.showThumb,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(size / 2, size / 2);
    final radius = (size - strokeWidth) / 2 - waveAmplitude;
    if (radius <= 0) return;

    // 1. Arco inactivo (siempre completo, como "riel").
    final inactivePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = inactiveColor;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startRad,
      sweepRad,
      false,
      inactivePaint,
    );

    // 2. Arco activo según el estilo.
    final activeSweep = sweepRad * progress;
    if (activeSweep > 0) {
      _paintActiveArc(
        canvas: canvas,
        center: center,
        radius: radius,
        activeSweep: activeSweep,
      );
    }

    // 3. Thumb (si aplica).
    if (showThumb && style != ArcProgressStyle.dots) {
      final thumbAngle = startRad + sweepRad * progress;
      final thumbCenter = Offset(
        center.dx + radius * math.cos(thumbAngle),
        center.dy + radius * math.sin(thumbAngle),
      );

      final thumbWidth = thumbSize * thumbWidthMultiplier;
      final thumbHeight = thumbSize * thumbHeightMultiplier;

      canvas
        ..save()
        ..translate(thumbCenter.dx, thumbCenter.dy)
        ..rotate(thumbAngle + math.pi / 2)
        ..translate(-thumbWidth / 2, -thumbHeight / 2);

      final thumbPath = m3ePath(
        thumbShape,
        Size(thumbWidth, thumbHeight),
        keepAspect: false,
      );
      canvas.drawPath(thumbPath, Paint()..color = thumbColor);

      canvas.drawPath(
        thumbPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = inactiveColor.withValues(alpha: 0.5),
      );

      canvas.restore();
    }
  }

  void _paintActiveArc({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double activeSweep,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);

    switch (style) {
      case ArcProgressStyle.normal:
      case ArcProgressStyle.rounded:
      case ArcProgressStyle.thin:
      case ArcProgressStyle.thick:
        canvas.drawArc(
          rect,
          startRad,
          activeSweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap =
                style == ArcProgressStyle.rounded ? StrokeCap.round : StrokeCap.butt
            ..color = activeColor,
        );
        break;

      case ArcProgressStyle.wavy:
        if (waveAmplitude > 0) {
          canvas.drawPath(
            _buildArcWavePath(
              center: center,
              radius: radius,
              startRad: startRad,
              sweepRad: activeSweep,
              amplitude: waveAmplitude,
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = activeColor,
          );
        } else {
          canvas.drawArc(
            rect,
            startRad,
            activeSweep,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeCap = StrokeCap.round
              ..color = activeColor,
          );
        }
        break;

      case ArcProgressStyle.gradient:
        final capAngle = (strokeWidth / 2.0) / radius;
        final shader = SweepGradient(
          startAngle: 0.0,
          endAngle: activeSweep + 2 * capAngle,
          colors: [_deepen(activeColor), activeColor],
          transform: GradientRotation(startRad - capAngle),
        ).createShader(rect);
        canvas.drawArc(
          rect,
          startRad,
          activeSweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round
            ..shader = shader,
        );
        break;

      case ArcProgressStyle.segmented:
        final segmentCount = 16;
        final segmentSweep = activeSweep / segmentCount;
        final gap = segmentSweep * 0.15;
        for (int i = 0; i < segmentCount; i++) {
          final s0 = startRad + i * segmentSweep + gap / 2;
          final s1 = segmentSweep - gap;
          if (s1 <= 0) continue;
          canvas.drawArc(
            rect,
            s0,
            s1,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeCap = StrokeCap.round
              ..color = activeColor,
          );
        }
        break;

      case ArcProgressStyle.dots:
        // Puntos distribuidos a lo largo del arco activo.
        final circumference = radius * activeSweep;
        final dotSpacing = strokeWidth * 1.6;
        final dotCount = math.max(1, (circumference / dotSpacing).floor());
        for (int i = 0; i < dotCount; i++) {
          final t = (i + 0.5) / dotCount;
          final angle = startRad + activeSweep * t;
          final dotCenter = Offset(
            center.dx + radius * math.cos(angle),
            center.dy + radius * math.sin(angle),
          );
          canvas.drawCircle(
            dotCenter,
            strokeWidth / 2,
            Paint()..color = activeColor,
          );
        }
        break;
    }
  }

  Path _buildArcWavePath({
    required Offset center,
    required double radius,
    required double startRad,
    required double sweepRad,
    required double amplitude,
  }) {
    final path = Path();
    final arcLength = radius * sweepRad;
    if (arcLength <= 0.0) return path;

    final a = math.min(amplitude, radius * 0.3);
    final wavelength = math.max(9.0, radius * 0.9);
    final ramp = math.min(wavelength * 0.75, arcLength / 2.0);
    final segments = math.max(waveSegments, (arcLength / 2.0).ceil());

    for (int i = 0; i <= segments; i++) {
      final s = arcLength * i / segments;
      final edge = math.min(s, arcLength - s);
      final t = ramp <= 0.0 ? 1.0 : (edge / ramp).clamp(0.0, 1.0);
      final envelope = t * t * (3 - 2 * t);
      final offset = a * envelope * math.sin(2 * math.pi * s / wavelength);
      final angle = startRad + sweepRad * i / segments;
      final r = radius + offset;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant _ArcWavePainter old) =>
      old.progress != progress ||
      old.size != size ||
      old.strokeWidth != strokeWidth ||
      old.thumbSize != thumbSize ||
      old.thumbShape != thumbShape ||
      old.thumbWidthMultiplier != thumbWidthMultiplier ||
      old.thumbHeightMultiplier != thumbHeightMultiplier ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor ||
      old.thumbColor != thumbColor ||
      old.waveAmplitude != waveAmplitude ||
      old.waveSegments != waveSegments ||
      old.startRad != startRad ||
      old.sweepRad != sweepRad ||
      old.style != style ||
      old.showThumb != showThumb;
}

Color _deepen(Color color, [double amount = 0.18]) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .toColor();
}