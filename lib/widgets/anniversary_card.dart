import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_components.dart';

/// Badge tonal con el tiempo transcurrido desde una fecha.
///
/// Se usa dentro de [RelationshipPreview] y dentro de [AnniversaryCard].
/// Formato: "2 años y 4 meses juntos" / "5 días juntos".
class AnniversaryBadge extends StatelessWidget {
  final DateTime startDate;

  const AnniversaryBadge({super.key, required this.startDate});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            timeTogether(startDate),
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// "2 años y 4 meses juntos", "5 días juntos", etc.
  static String timeTogether(DateTime start) {
    final now = DateTime.now();
    int years = now.year - start.year;
    int months = now.month - start.month;
    int days = now.day - start.day;

    if (days < 0) {
      months--;
      final prevMonth = DateTime(now.year, now.month, 0);
      days += prevMonth.day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }

    if (years > 0) {
      final yw = years == 1 ? 'año' : 'años';
      if (months > 0) {
        final mw = months == 1 ? 'mes' : 'meses';
        return '$years $yw y $months $mw juntos';
      }
      return '$years $yw juntos';
    }
    if (months > 0) {
      final mw = months == 1 ? 'mes' : 'meses';
      if (days > 0) {
        final dw = days == 1 ? 'día' : 'días';
        return '$months $mw y $days $dw juntos';
      }
      return '$months $mw juntos';
    }
    final dw = days == 1 ? 'día' : 'días';
    return '$days $dw juntos';
  }
}

/// Tarjeta Bento de fecha de aniversario. Estado vacío y estado configurado.
///
/// Reutilizable en `relationship_screen.dart` y en Home (tarjeta "Días
/// juntos"). No conoce providers: recibe `DateTime?` y `onTap`.
class AnniversaryCard extends StatelessWidget {
  final DateTime? startDate;
  final VoidCallback onTap;

  const AnniversaryCard({
    super.key,
    required this.startDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: BentoCard(
        child: Row(
          children: [
            TonalIconBubble(
              icon: startDate == null
                  ? Icons.event_outlined
                  : Icons.event_available_rounded,
              background: scheme.tertiaryContainer,
              foreground: scheme.onTertiaryContainer,
              size: 44,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Fecha de aniversario',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (startDate == null)
                    Text(
                      'Agrega el día que empezaron',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            formatExtendedDate(startDate!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        MiniChip(
                          label: daysAgoLabel(startDate!),
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
            Icon(
              startDate == null
                  ? Icons.add_circle_outline_rounded
                  : Icons.edit_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// "14 de febrero, 2022".
  static String formatExtendedDate(DateTime d) {
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

  /// "5 días", "2 meses", "3 años". Chip compacto.
  static String daysAgoLabel(DateTime start) {
    final days = DateTime.now().difference(start).inDays;
    if (days < 0) return 'Sin configurar';
    if (days == 0) return 'Hoy';
    if (days == 1) return '1 día';
    if (days < 30) return '$days días';
    final months = days ~/ 30;
    if (months < 12) return '$months ${months == 1 ? "mes" : "meses"}';
    final years = days ~/ 365;
    return '$years ${years == 1 ? "año" : "años"}';
  }
}