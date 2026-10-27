import 'package:flutter/material.dart';
import 'package:m3e_shapes/m3e_shapes.dart';

import 'arc_wave_progress.dart';

/// Cover con arc de progreso 270° alrededor.
///
/// Pensado para la isla colapsada. No tiene thumb: el progreso se lee
/// del largo del arco (y de la onda cuando `isPlaying == true`).
///
/// El estilo es configurable vía [style]. Usa el mismo painter que
/// `ArcWaveProgressBar` (con `showThumb: false`), así los 8 estilos
/// son idénticos en ambos widgets.
class MiniArcCover extends StatelessWidget {
  final double progress;
  final bool isPlaying;
  final double size;
  final M3EShape coverShape;
  final Widget? coverChild;
  final double strokeWidth;
  final double waveAmplitude;
  final ArcProgressStyle style;
  final Color? activeColor;
  final Color? inactiveColor;

  const MiniArcCover({
    super.key,
    required this.progress,
    this.isPlaying = true,
    this.size = 32.0,
    this.coverShape = M3EShape.circle,
    this.coverChild,
    this.strokeWidth = 3.5,
    this.waveAmplitude = 1.5,
    this.style = ArcProgressStyle.wavy,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activeColor ?? theme.colorScheme.primary;
    final inactive = inactiveColor ??
        theme.colorScheme.outlineVariant.withValues(alpha: 0.6);

    // El cover "real" es más chico que el arc, para que el arc lo
    // rodee sin superponerse.
    final coverPadding = strokeWidth + 2;
    final coverSize = size - coverPadding * 2;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cover en el centro.
          SizedBox(
            width: coverSize,
            height: coverSize,
            child: M3EClip(
              shape: coverShape,
              child: coverChild ??
                  ColoredBox(color: theme.colorScheme.primaryContainer),
            ),
          ),
          // Arc encima (sin thumb, sin capturar gestos).
          IgnorePointer(
            child: ArcWaveProgressBar(
              progress: progress,
              isPlaying: isPlaying,
              size: size,
              strokeWidth: strokeWidth,
              waveAmplitude: isPlaying ? waveAmplitude : 0.0,
              showThumb: false,
              style: style,
              activeColor: active,
              inactiveColor: inactive,
            ),
          ),
        ],
      ),
    );
  }
}