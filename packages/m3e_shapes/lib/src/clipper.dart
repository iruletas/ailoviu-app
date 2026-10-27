import 'dart:ui';

import 'package:androidx_graphics_shapes/androidx_graphics_shapes.dart';
import 'package:flutter/rendering.dart';

import 'path.dart';
import 'polygon.dart';
import 'shape.dart';

/// [CustomClipper] que recorta un widget con la forma [M3EShape] indicada.
///
/// Si [keepAspect] es `false` (default), la forma se estira al rect del
/// widget. Si es `true`, la forma mantiene su aspecto 1:1 y se centra.
class M3EClipper extends CustomClipper<Path> {
  final M3EShape shape;
  final bool keepAspect;

  const M3EClipper({
    required this.shape,
    this.keepAspect = false,
  });

  @override
  Path getClip(Size size) => m3ePath(shape, size, keepAspect: keepAspect);

  @override
  bool shouldReclip(covariant M3EClipper oldClipper) =>
      oldClipper.shape != shape || oldClipper.keepAspect != keepAspect;
}

/// [CustomClipper] que recorta un widget con el morph entre dos formas.
///
/// El [progress] va de 0.0 (solo [from]) a 1.0 (solo [to]).
class M3EMorphClipper extends CustomClipper<Path> {
  final M3EShape from;
  final M3EShape to;
  final double progress;
  final bool keepAspect;

  const M3EMorphClipper({
    required this.from,
    required this.to,
    required this.progress,
    this.keepAspect = false,
  });

  @override
  Path getClip(Size size) {
    if (size.width <= 0 || size.height <= 0) return Path();
    final morph = m3eMorphBetween(from, to);
    // `Morph.toPath` no acepta squash, así que el path resultante está
    // en espacio unitario. Lo escalamos al rect.
    final rawPath = morph.toPath(progress);
    final rect = Offset.zero & size;

    var scaleX = rect.width;
    var scaleY = rect.height;
    if (keepAspect) {
      final side = rect.shortestSide;
      scaleX = side;
      scaleY = side;
    }

    final dx = rect.left + (rect.width - scaleX) / 2.0;
    final dy = rect.top + (rect.height - scaleY) / 2.0;

    final matrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scaleX, scaleY);
    return rawPath.transform(matrix.storage);
  }

  @override
  bool shouldReclip(covariant M3EMorphClipper oldClipper) =>
      oldClipper.from != from ||
      oldClipper.to != to ||
      oldClipper.progress != progress ||
      oldClipper.keepAspect != keepAspect;
}

/// Cache LRU de morphes por par `(from, to)`.
const int _kMorphCacheSize = 20;
final Map<_MorphKey, Morph> _morphCache = <_MorphKey, Morph>{};

/// Devuelve el [Morph] entre [from] y [to], cacheado.
///
/// Crear un [Morph] matchea curvas de las dos formas (caro). Si dos
/// formas se van a morfear en cada frame de una animación, hay que
/// reusar el mismo `Morph`, no recrearlo.
///
/// Nota: `Morph` del paquete `androidx_graphics_shapes` usa un
/// constructor primario con dos parámetros **posicionales**
/// (`Morph(start, end)`), no named. Es la sintaxis de Dart 3.13
/// que el upstream adoptó en la migración.
Morph m3eMorphBetween(M3EShape from, M3EShape to) {
  if (from == to) {
    // Caso trivial: usamos el propio polygon como start y end.
    // MaterialShapes ya cachea internamente, así que esto es barato.
    final p = m3ePolygon(from);
    return Morph(p, p);
  }
  final key = _MorphKey(from: from, to: to);
  final cached = _morphCache.remove(key);
  if (cached != null) {
    _morphCache[key] = cached;
    return cached;
  }
  final morph = Morph(
    m3ePolygon(from),
    m3ePolygon(to),
  );
  if (_morphCache.length >= _kMorphCacheSize) {
    _morphCache.remove(_morphCache.keys.first);
  }
  _morphCache[key] = morph;
  return morph;
}

/// Limpia el cache de morphes.
void m3eMorphClearCache() {
  _morphCache.clear();
}

class _MorphKey {
  final M3EShape from;
  final M3EShape to;

  const _MorphKey({required this.from, required this.to});

  @override
  bool operator ==(Object other) =>
      other is _MorphKey && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}