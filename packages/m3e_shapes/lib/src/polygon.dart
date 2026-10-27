import 'package:androidx_graphics_shapes/androidx_graphics_shapes.dart';

import 'shape.dart';

/// Devuelve el [RoundedPolygon] de Material 3 Expressive para [shape].
///
/// Mapeo 1:1 con `MaterialShapes` del paquete upstream. Si el upstream
/// cambia una forma, solo se toca este archivo.
RoundedPolygon m3ePolygon(M3EShape shape) {
  switch (shape) {
    case M3EShape.circle:
      return MaterialShapes.circle;
    case M3EShape.square:
      return MaterialShapes.square;
    case M3EShape.slanted:
      return MaterialShapes.slanted;
    case M3EShape.arch:
      return MaterialShapes.arch;
    case M3EShape.semiCircle:
      return MaterialShapes.semiCircle;
    case M3EShape.oval:
      return MaterialShapes.oval;
    case M3EShape.pill:
      return MaterialShapes.pill;
    case M3EShape.triangle:
      return MaterialShapes.triangle;
    case M3EShape.arrow:
      return MaterialShapes.arrow;
    case M3EShape.fan:
      return MaterialShapes.fan;
    case M3EShape.diamond:
      return MaterialShapes.diamond;
    case M3EShape.clamShell:
      return MaterialShapes.clamShell;
    case M3EShape.pentagon:
      return MaterialShapes.pentagon;
    case M3EShape.gem:
      return MaterialShapes.gem;
    case M3EShape.sunny:
      return MaterialShapes.sunny;
    case M3EShape.verySunny:
      return MaterialShapes.verySunny;
    case M3EShape.cookie4Sided:
      return MaterialShapes.cookie4Sided;
    case M3EShape.cookie6Sided:
      return MaterialShapes.cookie6Sided;
    case M3EShape.cookie7Sided:
      return MaterialShapes.cookie7Sided;
    case M3EShape.cookie9Sided:
      return MaterialShapes.cookie9Sided;
    case M3EShape.cookie12Sided:
      return MaterialShapes.cookie12Sided;
    case M3EShape.clover4Leaf:
      return MaterialShapes.clover4Leaf;
    case M3EShape.clover8Leaf:
      return MaterialShapes.clover8Leaf;
    case M3EShape.burst:
      return MaterialShapes.burst;
    case M3EShape.softBurst:
      return MaterialShapes.softBurst;
    case M3EShape.boom:
      return MaterialShapes.boom;
    case M3EShape.softBoom:
      return MaterialShapes.softBoom;
    case M3EShape.flower:
      return MaterialShapes.flower;
    case M3EShape.puffy:
      return MaterialShapes.puffy;
    case M3EShape.puffyDiamond:
      return MaterialShapes.puffyDiamond;
    case M3EShape.ghostish:
      return MaterialShapes.ghostish;
    case M3EShape.pixelCircle:
      return MaterialShapes.pixelCircle;
    case M3EShape.pixelTriangle:
      return MaterialShapes.pixelTriangle;
    case M3EShape.bun:
      return MaterialShapes.bun;
    case M3EShape.heart:
      return MaterialShapes.heart;
  }
}