# m3e_shapes

Wrapper delgado sobre [`androidx_graphics_shapes`](https://pub.dev/packages/androidx_graphics_shapes) 2.0.0.

Expone las **35 formas de Material 3 Expressive** (`MaterialShapes`) con
una API tipada y estable para el proyecto Scrobbot, sin agregar lógica
propia. La fuente de verdad de las formas es el paquete de Google.

## API

```dart
import 'package:m3e_shapes/m3e_shapes.dart';

// Enum de 35 formas + categorías.
final shape = M3EShape.clover4Leaf;
final category = shape.category; // M3EShapeCategory.organic

// Path cacheado (LRU 200).
final path = m3ePath(shape, const Size(64, 64));

// Clip widget (equivale a ShapeClip de expressive_m3).
M3EClip(
  shape: M3EShape.heart,
  child: Image.network(...),
);

// Morph entre dos formas, con progress de 0.0 a 1.0.
final morph = m3eMorphBetween(M3EShape.circle, M3EShape.cookie9Sided);
final morphPath = morph.toPath(0.5);

// Clip morphing animado.
m3eMorphClip(
  from: M3EShape.circle,
  to: M3EShape.heart,
  progress: animation.value,
  child: child,
);

Atribuciones

Ver NOTICE. El paquete depende de androidx_graphics_shapes,
que es MIT (deminearchiver) y a su vez porta código Apache 2.0 (Google).