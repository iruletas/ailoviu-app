import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/relationship_providers.dart';
import '../widgets/relationship_preview.dart';

class RelationshipScreen extends ConsumerStatefulWidget {
  const RelationshipScreen({super.key});

  @override
  ConsumerState<RelationshipScreen> createState() =>
      _RelationshipScreenState();
}

class _RelationshipScreenState extends ConsumerState<RelationshipScreen> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    final rel = ref.read(relationshipProvider);
    final initialNames = List<String>.from(rel.partnerNames);
    while (initialNames.length < 3) {
      initialNames.add('');
    }
    for (int i = 0; i < 3; i++) {
      final controller = TextEditingController(text: initialNames[i]);
      final node = FocusNode();
      node.addListener(() {
        if (!node.hasFocus) {
          ref
              .read(relationshipProvider.notifier)
              .setNameAt(i, controller.text);
        }
      });
      _controllers.add(controller);
      _focusNodes.add(node);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final rel = ref.read(relationshipProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: rel.startDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Fecha de inicio',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      await ref.read(relationshipProvider.notifier).setStartDate(picked);
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar datos de la relación'),
        content: const Text(
          'Se eliminarán los nombres, el tipo de relación y la fecha de '
          'inicio. El tema y el color no se modifican.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(relationshipProvider.notifier).clear();
      for (final c in _controllers) {
        c.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rel = ref.watch(relationshipProvider);
    final theme = Theme.of(context);
    final visibleCount = rel.visibleCount;
    final hasAnyData = rel.partnerNames.any((n) => n.trim().isNotEmpty) ||
        rel.startDate != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Datos de la relación')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RelationshipPreview(),
              const SizedBox(height: 24),
              Text(
                'Tipo de relación',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<RelationshipType>(
                initialValue: rel.type,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final type in RelationshipType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          _RelationshipShape(type: type),
                          const SizedBox(width: 12),
                          Text(type.label),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    ref.read(relationshipProvider.notifier).setType(v);
                  }
                },
              ),
              const SizedBox(height: 24),
              Text('Nombres', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (int i = 0; i < visibleCount; i++) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    maxLength: 30,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: i < visibleCount - 1
                        ? TextInputAction.next
                        : TextInputAction.done,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(30),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Miembro ${String.fromCharCode(65 + i)}',
                      border: const OutlineInputBorder(),
                      counterText: '',
                    ),
                    onSubmitted: (v) {
                      ref
                          .read(relationshipProvider.notifier)
                          .setNameAt(i, v);
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Fecha de inicio',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  rel.startDate == null
                      ? 'Sin configurar'
                      : _formatDate(rel.startDate!),
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _pickDate,
              ),
              const SizedBox(height: 24),
              if (hasAnyData)
                TextButton.icon(
                  onPressed: _confirmClear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar datos de la relación'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}

class _RelationshipShape extends StatelessWidget {
  final RelationshipType type;
  const _RelationshipShape({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    const size = 20.0;

    switch (type) {
      case RelationshipType.hetero:
        return Icon(Icons.circle_outlined, size: size, color: color);
      case RelationshipType.lesbian:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _TrianglePainter(color)),
        );
      case RelationshipType.gay:
        return Icon(Icons.square_outlined, size: size, color: color);
      case RelationshipType.polyamorous:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _HexagonPainter(color)),
        );
      case RelationshipType.open:
        return Icon(Icons.diamond_outlined, size: size, color: color);
      case RelationshipType.other:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
        );
    }
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}

class _HexagonPainter extends CustomPainter {
  final Color color;
  _HexagonPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter old) => old.color != color;
}