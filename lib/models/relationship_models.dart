import 'package:flutter/foundation.dart';

/// Datos de la relación: dos personas y la fecha de inicio.
///
/// Índice 0 = quien configura la app (se muestra como "Tu nombre").
/// Índice 1 = tu amor ("Su nombre"). No hay tipos de relación
/// ni terceros miembros.
@immutable
class AppRelationship {
  final List<String> partnerNames;
  final DateTime? startDate;

  const AppRelationship({
    this.partnerNames = const ['', ''],
    this.startDate,
  });

  AppRelationship copyWith({
    List<String>? partnerNames,
    DateTime? startDate,
  }) {
    return AppRelationship(
      partnerNames: partnerNames ?? this.partnerNames,
      startDate: startDate ?? this.startDate,
    );
  }

  /// Siempre son dos personas.
  int get visibleCount => 2;

  List<String> get visibleNames => partnerNames.take(visibleCount).toList();
}
