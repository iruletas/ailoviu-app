import 'package:flutter/widgets.dart';

import 'clipper.dart';
import 'shape.dart';

/// Widget que recorta su [child] con una forma [M3EShape].
///
/// Equivalente a `ShapeClip` de `expressive_m3`, pero con las 35 formas
/// de Material 3 Expressive. Si [keepAspect] es `true`, la forma
/// mantiene su aspecto 1:1 y se centra en el widget.
class M3EClip extends StatelessWidget {
  final M3EShape shape;
  final Widget child;
  final bool keepAspect;

  const M3EClip({
    super.key,
    required this.shape,
    required this.child,
    this.keepAspect = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: M3EClipper(shape: shape, keepAspect: keepAspect),
      child: child,
    );
  }
}

/// Helper funcional que devuelve un [ClipPath] con la forma indicada.
///
/// Es azúcar sobre [M3EClip] para cuando el caller no necesita un
/// widget intermedio.
Widget m3eClip({
  required M3EShape shape,
  required Widget child,
  bool keepAspect = false,
}) {
  return M3EClip(shape: shape, keepAspect: keepAspect, child: child);
}

/// Widget que recorta su [child] con el morph entre [from] y [to].
///
/// [progress] va de 0.0 a 1.0. En 0.0 el clip es igual a [from], en 1.0
/// es igual a [to]. Cualquier valor intermedio produce un path morph.
class M3EMorphClip extends StatelessWidget {
  final M3EShape from;
  final M3EShape to;
  final double progress;
  final Widget child;
  final bool keepAspect;

  const M3EMorphClip({
    super.key,
    required this.from,
    required this.to,
    required this.progress,
    required this.child,
    this.keepAspect = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: M3EMorphClipper(
        from: from,
        to: to,
        progress: progress.clamp(0.0, 1.0),
        keepAspect: keepAspect,
      ),
      child: child,
    );
  }
}

/// Helper funcional que devuelve un [ClipPath] morphing.
Widget m3eMorphClip({
  required M3EShape from,
  required M3EShape to,
  required double progress,
  required Widget child,
  bool keepAspect = false,
}) {
  return M3EMorphClip(
    from: from,
    to: to,
    progress: progress,
    keepAspect: keepAspect,
    child: child,
  );
}