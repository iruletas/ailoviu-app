import 'package:flutter/foundation.dart';

/// Tipos de relación soportados hoy.
/// Solo [polyamorous] habilita el tercer miembro.
enum RelationshipType {
  hetero,
  lesbian,
  gay,
  polyamorous,
  open,
  other;

  String get label {
    switch (this) {
      case RelationshipType.hetero:
        return 'Hétero';
      case RelationshipType.lesbian:
        return 'Lesbiana';
      case RelationshipType.gay:
        return 'Gay';
      case RelationshipType.polyamorous:
        return 'Poliamor';
      case RelationshipType.open:
        return 'Abierta';
      case RelationshipType.other:
        return 'Otro';
    }
  }

  bool get allowsThirdMember => this == RelationshipType.polyamorous;
}

@immutable
class AppRelationship {
  final List<String> partnerNames;
  final RelationshipType type;
  final DateTime? startDate;

  const AppRelationship({
    this.partnerNames = const ['', ''],
    this.type = RelationshipType.hetero,
    this.startDate,
  });

  AppRelationship copyWith({
    List<String>? partnerNames,
    RelationshipType? type,
    DateTime? startDate,
  }) {
    return AppRelationship(
      partnerNames: partnerNames ?? this.partnerNames,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
    );
  }

  int get visibleCount => type.allowsThirdMember ? 3 : 2;

  List<String> get visibleNames => partnerNames.take(visibleCount).toList();
}