import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/relationship_providers.dart';
import 'settings_components.dart';

/// Dos layouts disponibles para [RelationshipSummaryCard].
///
/// - [hero]: card grande con gradiente, badge de estado y días.
///   Pensada para Settings, o para cualquier pantalla que quiera
///   destacar la relación como feature principal.
/// - [compact]: card de una fila con avatares + nombres + tipo + días.
///   Pensada para Home (lista de cards) o para contextos donde el
///   hero card ocuparía demasiado espacio vertical.
enum RelationshipCardVariant { hero, compact }

/// Card resumen de la relación, reutilizable en Settings y Home.
///
/// Si [relationship] es null, lee [relationshipProvider] automáticamente.
/// Si lo pasas, usa ese valor (útil para previews o tests).
class RelationshipSummaryCard extends ConsumerWidget {
  final AppRelationship? relationship;
  final VoidCallback? onTap;
  final RelationshipCardVariant variant;
  final bool showDays;
  final bool useHapticOnTap;

  const RelationshipSummaryCard({
    super.key,
    this.relationship,
    this.onTap,
    this.variant = RelationshipCardVariant.hero,
    this.showDays = true,
    this.useHapticOnTap = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Si el caller no pasa relación, leemos del provider.
    // El `??` garantiza que `rel` es no-null.
    final rel = relationship ?? ref.watch(relationshipProvider);

    if (variant == RelationshipCardVariant.hero) {
      return _HeroCard(
        relationship: rel,
        onTap: onTap,
        showDays: showDays,
        useHapticOnTap: useHapticOnTap,
      );
    }
    return _CompactCard(
      relationship: rel,
      onTap: onTap,
      showDays: showDays,
      useHapticOnTap: useHapticOnTap,
    );
  }
}

// ── Helpers compartidos ───────────────────────────────────────────────────
String _formatDate(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

List<String> _visibleNames(AppRelationship rel) => rel.visibleNames
    .map((n) => n.trim())
    .where((n) => n.isNotEmpty)
    .toList();

int? _daysTogether(AppRelationship rel) {
  if (rel.startDate == null) return null;
  return DateTime.now().difference(rel.startDate!).inDays;
}

void _fireHaptic(bool useHaptic) {
  if (useHaptic) HapticFeedback.mediumImpact();
}

// ── Hero card ─────────────────────────────────────────────────────────────
class _HeroCard extends StatefulWidget {
  final AppRelationship relationship;
  final VoidCallback? onTap;
  final bool showDays;
  final bool useHapticOnTap;

  const _HeroCard({
    required this.relationship,
    required this.onTap,
    required this.showDays,
    required this.useHapticOnTap,
  });

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    _fireHaptic(widget.useHapticOnTap);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final rel = widget.relationship;

    final names = _visibleNames(rel);
    final hasAnyData = names.isNotEmpty || rel.startDate != null;
    final days = _daysTogether(rel);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null ? null : _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer,
                Color.alphaBlend(
                  scheme.tertiaryContainer.withValues(alpha: 0.45),
                  scheme.primaryContainer,
                ),
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: scheme.onPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Datos de la relación',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rel.type.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer
                                .withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onTap != null)
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (!hasAnyData)
                PillStatus(
                  label: 'Sin configurar · Toca para empezar',
                  background: scheme.errorContainer,
                  foreground: scheme.onErrorContainer,
                )
              else ...[
                if (names.isNotEmpty)
                  Text(
                    names.join(' & '),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (widget.showDays && days != null)
                      PillStatus(
                        label:
                            '$days ${days == 1 ? 'día' : 'días'} juntos',
                        background: scheme.surface.withValues(alpha: 0.55),
                        foreground: scheme.onPrimaryContainer,
                      ),
                    if (rel.startDate != null)
                      PillStatus(
                        label: 'Desde ${_formatDate(rel.startDate!)}',
                        background: scheme.surface.withValues(alpha: 0.55),
                        foreground: scheme.onPrimaryContainer,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compact card ──────────────────────────────────────────────────────────
class _CompactCard extends StatefulWidget {
  final AppRelationship relationship;
  final VoidCallback? onTap;
  final bool showDays;
  final bool useHapticOnTap;

  const _CompactCard({
    required this.relationship,
    required this.onTap,
    required this.showDays,
    required this.useHapticOnTap,
  });

  @override
  State<_CompactCard> createState() => _CompactCardState();
}

class _CompactCardState extends State<_CompactCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    _fireHaptic(widget.useHapticOnTap);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final rel = widget.relationship;

    final names = _visibleNames(rel);
    final hasAnyData = names.isNotEmpty || rel.startDate != null;
    final days = _daysTogether(rel);
    final displayNames =
        names.isEmpty ? 'Sin nombres' : names.join(' & ');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null ? null : _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              TonalIconBubble(
                icon: Icons.favorite_rounded,
                background: scheme.primaryContainer,
                foreground: scheme.onPrimaryContainer,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasAnyData ? rel.type.label : 'Sin configurar',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showDays && days != null) ...[
                const SizedBox(width: 8),
                MiniChip(
                  label: '$days ${days == 1 ? 'día' : 'días'}',
                  background: scheme.primaryContainer,
                  foreground: scheme.onPrimaryContainer,
                  bold: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}