import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:m3e_shapes/m3e_shapes.dart';

/// Selector visual de una opción usando una forma M3E.
///
/// Genérico: recibe un [M3EShape], un label, un estado selected y un
/// callback. No conoce nada del dominio de la app.
///
/// Se usa en `relationship_screen.dart` con las formas de cada
/// `RelationshipType`. Puede reusarse para un futuro selector de
/// iconos de avatar (PENDIENTES ítem 7) o de cualquier otra opción
/// representable con forma.
class ShapeSelectorCard extends StatefulWidget {
  final M3EShape shape;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double width;
  final double shapeSize;

  const ShapeSelectorCard({
    super.key,
    required this.shape,
    required this.label,
    required this.selected,
    required this.onTap,
    this.width = 100,
    this.shapeSize = 32,
  });

  @override
  State<ShapeSelectorCard> createState() => _ShapeSelectorCardState();
}

class _ShapeSelectorCardState extends State<ShapeSelectorCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final selected = widget.selected;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : (selected ? 1.08 : 1.0),
        duration: const Duration(milliseconds: 180),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: widget.width,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShapeIcon(
                shape: widget.shape,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                filled: selected,
                size: widget.shapeSize,
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ícono de forma M3E que puede alternar entre outlined y filled
/// con fade suave. `m3e_shapes` recorta (clip), no dibuja bordes, así
/// que la capa outlined se dibuja con [CustomPaint].
class ShapeIcon extends StatelessWidget {
  final M3EShape shape;
  final Color color;
  final bool filled;
  final double size;

  const ShapeIcon({
    super.key,
    required this.shape,
    required this.color,
    required this.filled,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: ShapePainter(
              shape: shape,
              color: color,
              filled: false,
            ),
          ),
          AnimatedOpacity(
            opacity: filled ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: CustomPaint(
              size: Size(size, size),
              painter: ShapePainter(
                shape: shape,
                color: color,
                filled: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShapePainter extends CustomPainter {
  final M3EShape shape;
  final Color color;
  final bool filled;

  ShapePainter({
    required this.shape,
    required this.color,
    required this.filled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 1.5;
    final inner = Size(size.width - inset * 2, size.height - inset * 2);
    final path = m3ePath(shape, inner);
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;

    canvas
      ..save()
      ..translate(inset, inset)
      ..drawPath(path, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant ShapePainter old) =>
      old.shape != shape || old.color != color || old.filled != filled;
}