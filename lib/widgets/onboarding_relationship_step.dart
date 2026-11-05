import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/onboarding_providers.dart';
import '../providers/relationship_providers.dart';
import 'anniversary_card.dart';
import 'onboarding_scaffold.dart';
import 'relationship_preview.dart';
import 'settings_components.dart';

/// Paso 2: Nombres y fecha de inicio. El primer campo es de quien
/// configura la app; no hay tipos de relación.
///
/// Reutiliza `RelationshipPreview` (preview en vivo) y el picker de fecha
/// M3 oficial. Toda la
/// persistencia está en `relationshipProvider`; este widget solo la
/// invoca.
class OnboardingRelationshipStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const OnboardingRelationshipStep({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  @override
  ConsumerState<OnboardingRelationshipStep> createState() =>
      _OnboardingRelationshipStepState();
}

class _OnboardingRelationshipStepState
    extends ConsumerState<OnboardingRelationshipStep> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    final rel = ref.read(relationshipProvider);
    final initialNames = List<String>.from(rel.partnerNames);
    while (initialNames.length < 2) {
      initialNames.add('');
    }
    _controllers = List.generate(
      2,
      (i) => TextEditingController(text: initialNames[i]),
    );
    _focusNodes = List.generate(2, (_) => FocusNode());
    for (int i = 0; i < 2; i++) {
      final index = i;
      _focusNodes[i].addListener(() {
        if (!_focusNodes[index].hasFocus) {
          ref
              .read(relationshipProvider.notifier)
              .setNameAt(index, _controllers[index].text);
        }
      });
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

  @override
  Widget build(BuildContext context) {
    final rel = ref.watch(relationshipProvider);
    final notifier = ref.read(relationshipProvider.notifier);
    final hasAnyData =
        rel.partnerNames.any((n) => n.trim().isNotEmpty) ||
            rel.startDate != null;

    return OnboardingScaffold(
      step: OnboardingStep.relationship,
      onSkip: widget.onSkip,
      bottomAction: _BottomNav(
        onBack: widget.onBack,
        primaryLabel: hasAnyData ? 'Continuar' : 'Saltar por ahora',
        onPrimary: () {
          HapticFeedback.mediumImpact();
          // Guardado final por si el último campo no perdió el foco.
          for (int i = 0; i < 2; i++) {
            notifier.setNameAt(i, _controllers[i].text);
          }
          widget.onNext();
        },
        primaryIsSecondaryStyle: !hasAnyData,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          Text(
            'Su relación',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cuéntanos cómo se llaman y desde cuándo son novios. '
            'Puedes cambiarlo después.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 20),

          // Preview en vivo.
          const RelationshipPreview(),
          const SizedBox(height: 20),

          // Nombres: el primero es de quien configura.
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TonalMicroHeader(
                  icon: Icons.people_outline,
                  title: 'Nombres',
                  description:
                      'Se guardan automáticamente mientras escribes.',
                ),
                const SizedBox(height: 16),
                _MemberField(
                  letter: 'A',
                  hint: 'Tu nombre',
                  controller: _controllers[0],
                  focusNode: _focusNodes[0],
                  isLast: false,
                  onSubmit: (v) => notifier.setNameAt(0, v),
                ),
                const SizedBox(height: 12),
                _MemberField(
                  letter: 'B',
                  hint: 'Su nombre',
                  controller: _controllers[1],
                  focusNode: _focusNodes[1],
                  isLast: true,
                  onSubmit: (v) => notifier.setNameAt(1, v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fecha de inicio (reactiva a si hay fecha).
          _DateCard(
            startDate: rel.startDate,
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// _MemberField — campo de nombre con insignia reactiva al foco
// ══════════════════════════════════════════════════════════════════════

class _MemberField extends StatelessWidget {
  final String letter;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLast;
  final ValueChanged<String> onSubmit;

  const _MemberField({
    required this.letter,
    required this.hint,
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
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      inputFormatters: [LengthLimitingTextInputFormatter(30)],
      onSubmitted: onSubmit,
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: focused
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerHigh,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
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
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: focused
                    ? scheme.primaryContainer
                    : scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(focused ? 12 : 18),
              ),
              child: Text(
                letter,
                style: TextStyle(
                  color: focused
                      ? scheme.onPrimaryContainer
                      : scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
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

// ══════════════════════════════════════════════════════════════════════
// _DateCard — tarjeta de fecha reactiva a si hay valor
// ══════════════════════════════════════════════════════════════════════

class _DateCard extends StatelessWidget {
  final DateTime? startDate;
  final VoidCallback onTap;

  const _DateCard({
    required this.startDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hasDate = startDate != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasDate
            ? scheme.tertiaryContainer.withValues(alpha: 0.65)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasDate
                  ? scheme.tertiaryContainer
                  : scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasDate
                  ? Icons.event_available_rounded
                  : Icons.event_outlined,
              size: 22,
              color: hasDate
                  ? scheme.onTertiaryContainer
                  : scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Fecha de inicio',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                if (!hasDate)
                  Text(
                    'Agrega el día que empezaron',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _formatDate(startDate!),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      MiniChip(
                        label: _daysLabel(startDate!),
                        background: scheme.tertiaryContainer,
                        foreground: scheme.onTertiaryContainer,
                        bold: true,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            icon: Icon(
              hasDate ? Icons.edit_outlined : Icons.add_rounded,
            ),
            style: IconButton.styleFrom(
              backgroundColor: hasDate
                  ? scheme.tertiaryContainer
                  : scheme.secondaryContainer,
              foregroundColor: hasDate
                  ? scheme.onTertiaryContainer
                  : scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${d.day} de ${months[d.month - 1]}, ${d.year}';
  }

  static String _daysLabel(DateTime start) {
    final days = DateTime.now().difference(start).inDays;
    if (days < 0) return 'En el futuro';
    if (days == 0) return 'Hoy';
    if (days == 1) return '1 día';
    if (days < 30) return '$days días';
    final months = days ~/ 30;
    if (months < 12) return '$months ${months == 1 ? "mes" : "meses"}';
    final years = days ~/ 365;
    return '$years ${years == 1 ? "año" : "años"}';
  }
}

// ══════════════════════════════════════════════════════════════════════
// _BottomNav — superficie flotante con morphing implícito del primario
// ══════════════════════════════════════════════════════════════════════

class _BottomNav extends StatelessWidget {
  final VoidCallback onBack;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool primaryIsSecondaryStyle;

  const _BottomNav({
    required this.onBack,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIsSecondaryStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final bg = primaryIsSecondaryStyle
        ? scheme.surfaceContainerHighest
        : scheme.primary;
    final fg = primaryIsSecondaryStyle
        ? scheme.onSurface
        : scheme.onPrimary;
    final borderColor = primaryIsSecondaryStyle
        ? scheme.outlineVariant.withValues(alpha: 0.4)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () {
              HapticFeedback.lightImpact();
              onBack();
            },
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurface,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPrimary,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: 48,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: borderColor,
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: onPrimary,
                    borderRadius: BorderRadius.circular(24),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: fg,
                          ),
                          const SizedBox(width: 8),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            style: theme.textTheme.labelLarge!.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w600,
                            ),
                            child: Text(primaryLabel),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}