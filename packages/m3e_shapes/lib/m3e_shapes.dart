/// Wrapper delgado sobre `androidx_graphics_shapes` 2.0.0.
///
/// Expone las 35 formas de Material 3 Expressive con una API tipada y
/// estable para el proyecto Scrobbot.
///
/// Ejemplo:
///
/// ```dart
/// import 'package:m3e_shapes/m3e_shapes.dart';
///
/// M3EClip(
///   shape: M3EShape.heart,
///   child: Image.network(...),
/// );
/// ```
library;

export 'src/clipper.dart' show M3EClipper, M3EMorphClipper, m3eMorphBetween, m3eMorphClearCache;
export 'src/path.dart' show m3ePath, m3ePathClearCache, m3ePathCacheSize;
export 'src/polygon.dart' show m3ePolygon;
export 'src/shape.dart' show M3EShape, M3EShapeCategory, M3EShapeCategoryLabel, M3EShapeCategoryLookup, M3EShapeLookup;
export 'src/widgets.dart' show M3EClip, M3EMorphClip, m3eClip, m3eMorphClip;