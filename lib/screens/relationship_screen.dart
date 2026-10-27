import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_shapes/m3e_shapes.dart';

import '../providers/relationship_providers.dart';
import '../widgets/anniversary_card.dart';
import '../widgets/danger_action_card.dart';
import '../widgets/relationship_preview.dart';
import '../widgets/settings_components.dart';
import '../widgets/shape_selector_card.dart';
import '../widgets/tonal_back_button.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: rel.startDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Fecha de inicio',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(36),
              ),
              headerBackgroundColor: scheme.primaryContainer,
              headerForegroundColor: scheme.onPrimaryContainer,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      await ref.read(relationshipProvider.notifier).setStartDate(picked);
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Eliminar datos de la relación',
      message:
          'Se eliminarán los nombres, el tipo de relación y la fecha de '
          'inicio. El tema y el color no se modifican.',
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
    final notifier = ref.read(relationshipProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final visibleCount = rel.visibleCount;
    final hasAnyData =
        rel.partnerNames.any((n) => n.trim().isNotEmpty) ||
            rel.startDate != null;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar.large(
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: TonalBackButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            title: Text(
              'Datos de la relación',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const RelationshipPreview(),
                const SizedBox(height: 24),
                BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TonalMicroHeader(
                        icon: Icons.favorite_outline,
                        title: 'Tipo de relación',
                        description:
                            'Elige la etiqueta que mejor describa su vínculo.',
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final type in RelationshipType.values)
                            ShapeSelectorCard(
                              shape: _shapeForType(type),
                              label: type.label,
                              selected: rel.type == type,
                              onTap: () => notifier.setType(type),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TonalMicroHeader(
                        icon: Icons.people_outline,
                        title: 'Integrantes',
                        description:
                            'Sus nombres se guardan automáticamente.',
                      ),
                      const SizedBox(height: 20),
                      for (int i = 0; i < visibleCount; i++) ...[
                        AnimatedBuilder(
                          animation: _focusNodes[i],
                          builder: (context, _) => _MemberField(
                            letter: String.fromCharCode(65 + i),
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            isLast: i == visibleCount - 1,
                            onSubmit: (v) => notifier.setNameAt(i, v),
                          ),
                        ),
                        if (i < visibleCount - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AnniversaryCard(
                  startDate: rel.startDate,
                  onTap: _pickDate,
                ),
                if (hasAnyData) ...[
                  const SizedBox(height: 16),
                  DangerActionCard(
                    label: 'Restablecer datos de la relación',
                    onTap: _confirmClear,
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static M3EShape _shapeForType(RelationshipType type) {
    switch (type) {
      case RelationshipType.hetero:
        return M3EShape.circle;
      case RelationshipType.lesbian:
        return M3EShape.triangle;
      case RelationshipType.gay:
        return M3EShape.square;
      case RelationshipType.polyamorous:
        return M3EShape.cookie6Sided;
      case RelationshipType.open:
        return M3EShape.diamond;
      case RelationshipType.other:
        return M3EShape.arch;
    }
  }
}

class _MemberField extends StatelessWidget {
  final String letter;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLast;
  final ValueChanged<String> onSubmit;

  const _MemberField({
    required this.letter,
    required this.controller,
    required this.focusNode,
    required this.isLast,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focused = focusNode.hasFocus;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLength: 30,
      textCapitalization: TextCapitalization.words,
      textInputAction:
          isLast ? TextInputAction.done : TextInputAction.next,
      inputFormatters: [LengthLimitingTextInputFormatter(30)],
      onSubmitted: onSubmit,
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: focused
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerHigh,
        hintText: 'Nombre del miembro $letter',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: AnimatedScale(
            scale: focused ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: Center(
              widthFactor: 1,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 56,
          minHeight: 56,
        ),
      ),
    );
  }
}