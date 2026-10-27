import 'dart:ui';

import 'package:androidx_graphics_shapes/androidx_graphics_shapes.dart';

import 'polygon.dart';
import 'shape.dart';

/// Tamaño máximo del cache de paths.
const int _kPathCacheSize = 200;

/// Cache LRU de paths por `(shape, width, height, keepAspect)`.
///
/// Cada entrada guarda el path ya construido para un tamaño concreto,
/// así un ListView que muestra 40 covers de 48px solo construye cada
/// path una vez.
final Map<_M3EPathKey, Path> _pathCache = <_M3EPathKey, Path>{};

/// Devuelve el [Path] de [shape] ajustado a [size].
///
/// Si [keepAspect] es `false` (default), el path cubre el rect completo
/// con la forma estirada al aspecto de [size]. Si es `true`, el path
/// respeta el aspecto 1:1 de la forma y centra el resultado, dejando
/// márgenes en la dimensión más larga.
Path m3ePath(
  M3EShape shape,
  Size size, {
  bool keepAspect = false,
}) {
  if (size.width <= 0 || size.height <= 0) return Path();

  final key = _M3EPathKey(
    shape: shape,
    width: size.width.round(),
    height: size.height.round(),
    keepAspect: keepAspect,
  );

  final cached = _pathCache.remove(key);
  if (cached != null) {
    // Reinsertar al final para LRU.
    _pathCache[key] = cached;
    return cached;
  }

  final polygon = m3ePolygon(shape);
  final border = MaterialShapeBorder(
    shape: polygon,
    squash: keepAspect ? 0.0 : 1.0,
  );
  final path = border.getOuterPath(Offset.zero & size);

  if (_pathCache.length >= _kPathCacheSize) {
    // Evict LRU.
    _pathCache.remove(_pathCache.keys.first);
  }
  _pathCache[key] = path;
  return path;
}

/// Limpia el cache de paths. Útil para tests y para liberar memoria
/// cuando la app entra en background prolongado.
void m3ePathClearCache() {
  _pathCache.clear();
}

/// Cuántos paths hay cacheados.
int m3ePathCacheSize() => _pathCache.length;

/// Clave value-object para el cache LRU.
class _M3EPathKey {
  final M3EShape shape;
  final int width;
  final int height;
  final bool keepAspect;

  const _M3EPathKey({
    required this.shape,
    required this.width,
    required this.height,
    required this.keepAspect,
  });

  @override
  bool operator ==(Object other) =>
      other is _M3EPathKey &&
      other.shape == shape &&
      other.width == width &&
      other.height == height &&
      other.keepAspect == keepAspect;

  @override
  int get hashCode => Object.hash(shape, width, height, keepAspect);
}