import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'arc_wave_progress.dart';

/// Los 10 estilos visuales de barra lineal.
enum LinearProgressStyle {
  normal,
  wavy,
  wave,
  rounded,
  thin,
  thick,
  gradient,
  glow,
  segmented,
  dots,
}

extension LinearProgressStyleLabel on LinearProgressStyle {
  String get label {
    switch (this) {
      case LinearProgressStyle.normal:
        return 'Normal';
      case LinearProgressStyle.wavy:
        return 'Onda';
      case LinearProgressStyle.wave:
        return 'Wave';
      case LinearProgressStyle.rounded:
        return 'Redondeada';
      case LinearProgressStyle.thin:
        return 'Delgada';
      case LinearProgressStyle.thick:
        return 'Gruesa';
      case LinearProgressStyle.gradient:
        return 'Gradiente';
      case LinearProgressStyle.glow:
        return 'Destello';
      case LinearProgressStyle.segmented:
        return 'Segmentada';
      case LinearProgressStyle.dots:
        return 'Puntos';
    }
  }

  String get key => name;

  /// Convierte este estilo lineal al `ArcProgressStyle` equivalente.
  /// Útil para que el usuario elija un solo estilo y se aplique en
  /// ambos widgets (barra y arc).
  ArcProgressStyle toArcStyle() {
    switch (this) {
      case LinearProgressStyle.normal:
        return ArcProgressStyle.normal;
      case LinearProgressStyle.wavy:
      case LinearProgressStyle.wave:
        return ArcProgressStyle.wavy;
      case LinearProgressStyle.rounded:
        return ArcProgressStyle.rounded;
      case LinearProgressStyle.thin:
        return ArcProgressStyle.thin;
      case LinearProgressStyle.thick:
        return ArcProgressStyle.thick;
      case LinearProgressStyle.gradient:
      case LinearProgressStyle.glow:
        return ArcProgressStyle.gradient;
      case LinearProgressStyle.segmented:
        return ArcProgressStyle.segmented;
      case LinearProgressStyle.dots:
        return ArcProgressStyle.dots;
    }
  }

  static LinearProgressStyle fromKey(String? key) {
    if (key == null || key.isEmpty) return LinearProgressStyle.rounded;
    for (final s in LinearProgressStyle.values) {
      if (s.name == key) return s;
    }
    return LinearProgressStyle.rounded;
  }
}

Path buildLinearTrackPath({
  required LinearProgressStyle style,
  required double progress,
  required double trackWidth,
  required double trackHeight,
  double waveAmplitude = 4.0,
  double waveWavelength = 32.0,
}) {
  final clamped = progress.clamp(0.0, 1.0);
  final activeWidth = trackWidth * clamped;

  if (activeWidth <= 0.0 || trackHeight <= 0.0) {
    return Path();
  }

  switch (style) {
    case LinearProgressStyle.normal:
      return _pathRectangle(
        width: activeWidth,
        height: trackHeight,
        radius: 0.0,
      );
    case LinearProgressStyle.rounded:
    case LinearProgressStyle.gradient:
    case LinearProgressStyle.glow:
      return _pathRectangle(
        width: activeWidth,
        height: trackHeight,
        radius: trackHeight / 2.0,
      );
    case LinearProgressStyle.thin:
      return _pathRectangle(
        width: activeWidth,
        height: trackHeight,
        radius: math.min(trackHeight / 2.0, 2.0),
      );
    case LinearProgressStyle.thick:
      return _pathRectangle(
        width: activeWidth,
        height: trackHeight,
        radius: trackHeight / 2.0,
      );
    case LinearProgressStyle.wavy:
    case LinearProgressStyle.wave:
      return _pathRectangle(
        width: activeWidth,
        height: trackHeight,
        radius: trackHeight / 2.0,
      );
    case LinearProgressStyle.segmented:
      return _pathSegmented(
        width: activeWidth,
        height: trackHeight,
        totalWidth: trackWidth,
        segmentCount: 16,
      );
    case LinearProgressStyle.dots:
      return _pathDots(
        width: activeWidth,
        height: trackHeight,
      );
  }
}

Path _pathRectangle({
  required double width,
  required double height,
  required double radius,
}) {
  final r = radius.clamp(0.0, height / 2.0);
  return Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        Radius.circular(r),
      ),
    );
}

Path buildWavyCenterline({
  required double startX,
  required double endX,
  required double centerY,
  required double amplitude,
  required double wavelength,
  double phase = 0.0,
}) {
  final path = Path();
  final length = endX - startX;
  if (length <= 0.0) return path;

  final period = math.max(8.0, wavelength);
  final k = 2 * math.pi / period;
  final ramp = math.min(period * 0.75, length / 2.0);
  final steps = math.max(8, (length / 2.0).ceil());

  for (int i = 0; i <= steps; i++) {
    final d = length * i / steps;
    final edge = math.min(d, length - d);
    final t = ramp <= 0.0 ? 1.0 : (edge / ramp).clamp(0.0, 1.0);
    final envelope = t * t * (3 - 2 * t);
    final x = startX + d;
    final y = centerY + amplitude * envelope * math.sin(k * d - phase);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path;
}

Path _pathSegmented({
  required double width,
  required double height,
  required double totalWidth,
  required int segmentCount,
}) {
  if (totalWidth <= 0.0 || segmentCount <= 0) {
    return _pathRectangle(width: width, height: height, radius: height / 2.0);
  }

  final gap = 4.0;
  final totalGaps = (segmentCount - 1) * gap;
  final segmentWidth = (totalWidth - totalGaps) / segmentCount;
  if (segmentWidth <= 0.0) {
    return _pathRectangle(width: width, height: height, radius: height / 2.0);
  }

  final path = Path();
  final radius = math.min(segmentWidth / 2.0, height / 2.0);

  for (int i = 0; i < segmentCount; i++) {
    final x0 = i * (segmentWidth + gap);
    final x1 = x0 + segmentWidth;
    if (x0 >= width) break;
    final visibleRight = math.min(x1, width);
    final visibleWidth = visibleRight - x0;
    if (visibleWidth <= 0.0) continue;
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x0, 0, visibleWidth, height),
        Radius.circular(radius),
      ),
    );
  }
  return path;
}

Path _pathDots({
  required double width,
  required double height,
}) {
  if (width <= 0.0 || height <= 0.0) return Path();

  final dotDiameter = height;
  final spacing = dotDiameter + 4.0;
  final count = math.max(1, (width / spacing).floor());

  final path = Path();
  final radius = dotDiameter / 2.0;
  final centerY = height / 2.0;

  for (int i = 0; i < count; i++) {
    final cx = radius + i * spacing;
    if (cx > width) break;
    path.addOval(
      Rect.fromCircle(center: Offset(cx, centerY), radius: radius),
    );
  }
  return path;
}