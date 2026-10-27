# m3e_progress

Widgets de progreso para Material 3 Expressive, sobre
[`m3e_shapes`](../m3e_shapes) y `androidx_graphics_shapes`.

## API

```dart
import 'package:m3e_progress/m3e_progress.dart';

// Barra lineal con 8 estilos.
M3ELinearProgressBar(
  progress: 0.42,
  style: LinearProgressStyle.wavy,
  isPlaying: true,
);

// Barra con thumb arrastrable (scrub).
M3ELinearProgressWithThumb(
  progress: 0.42,
  style: LinearProgressStyle.rounded,
  thumbShape: M3EShape.circle,
  isPlaying: true,
  onSeek: (p) => player.seekTo(p),
);

// WaveSlider (wavy con scrub completo).
WaveSlider(
  progress: 0.42,
  isPlaying: true,
  onSeek: (p) => player.seekTo(p),
);

// ArcWaveProgressBar (270°, con onda).
ArcWaveProgressBar(
  progress: 0.42,
  isPlaying: true,
  size: 120,
  onSeek: (p) => player.seekTo(p),
);

// MorphingPlayPauseButton (circle ↔ cookie9Sided, rotación lenta).
MorphingPlayPauseButton(
  isPlaying: isPlaying,
  onPressed: () => player.togglePlayPause(),
);
```

Estilos de barra

normal, wavy, rounded, thin, thick, gradient, segmented, dots.

Atribuciones

Ver NOTICE. Idea conceptual inspirada en Rhythm (GPL v3)
sin copiar código. Depende de m3e_shapes (MIT) y androidx_graphics_shapes
(Apache 2.0).