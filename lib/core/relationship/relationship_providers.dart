import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Claves (prefijo relationship.) ────────────────────────────────────────
const _kPartnerNames = 'relationship.partnerNames';
const _kType = 'relationship.type';
const _kStartDate = 'relationship.startDate';

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
        return 'Hetero';
      case RelationshipType.lesbian:
        return 'Lesbiana';
      case RelationshipType.gay:
        return 'Gay';
      case RelationshipType.polyamorous:
        return 'Poliamor / Trio';
      case RelationshipType.open:
        return 'Abierta';
      case RelationshipType.other:
        return 'Otro';
    }
  }

  bool get allowsThirdMember => this == RelationshipType.polyamorous;
}

/// Estado inmutable de la relación.
@immutable
class AppRelationship {
  /// Nombres de los miembros. Longitud 2 o 3.
  /// Índice 0 = miembro A, 1 = miembro B, 2 = miembro C (si aplica).
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

  /// Número de miembros visibles según el tipo de relación.
  int get visibleCount => type.allowsThirdMember ? 3 : 2;

  /// Nombres visibles (recortados a [visibleCount]).
  List<String> get visibleNames => partnerNames.take(visibleCount).toList();
}

// ── Notifier con persistencia ──────────────────────────────────────────────
class RelationshipNotifier extends StateNotifier<AppRelationship> {
  RelationshipNotifier() : super(const AppRelationship()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final names = prefs.getStringList(_kPartnerNames);
    final typeStr = prefs.getString(_kType);
    final startIso = prefs.getString(_kStartDate);

    state = AppRelationship(
      partnerNames: names ?? const ['', ''],
      type: _parseType(typeStr),
      startDate: startIso != null ? DateTime.tryParse(startIso) : null,
    );
  }

  static RelationshipType _parseType(String? s) {
    return RelationshipType.values.firstWhere(
      (t) => t.name == s,
      orElse: () => RelationshipType.hetero,
    );
  }

  Future<void> _persistNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kPartnerNames, state.partnerNames);
  }

  Future<void> setNameAt(int index, String name) async {
    final trimmed = name.trim();
    final updated = List<String>.from(state.partnerNames);
    while (updated.length <= index) {
      updated.add('');
    }
    updated[index] = trimmed;
    state = state.copyWith(partnerNames: updated);
    await _persistNames();
  }

  Future<void> setType(RelationshipType type) async {
    final updatedNames = List<String>.from(state.partnerNames);
    // Garantiza al menos 3 entradas si el tipo habilita el tercero.
    if (type.allowsThirdMember && updatedNames.length < 3) {
      updatedNames.add('');
    }
    state = AppRelationship(
      partnerNames: updatedNames,
      type: type,
      startDate: state.startDate,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kType, type.name);
    await _persistNames();
  }

  Future<void> setStartDate(DateTime? date) async {
    state = AppRelationship(
      partnerNames: state.partnerNames,
      type: state.type,
      startDate: date,
    );
    final prefs = await SharedPreferences.getInstance();
    if (date == null) {
      await prefs.remove(_kStartDate);
    } else {
      await prefs.setString(_kStartDate, date.toIso8601String());
    }
  }

  Future<void> clear() async {
    state = const AppRelationship();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPartnerNames);
    await prefs.remove(_kType);
    await prefs.remove(_kStartDate);
  }
}

final relationshipProvider =
    StateNotifierProvider<RelationshipNotifier, AppRelationship>(
  (ref) => RelationshipNotifier(),
);