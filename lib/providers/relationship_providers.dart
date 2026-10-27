import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/relationship_models.dart';
import 'prefs_provider.dart';

export '../models/relationship_models.dart';

// ── Claves (prefijo relationship.) ────────────────────────────────────────
const _kPartnerNames = 'relationship.partnerNames';
const _kType = 'relationship.type';
const _kStartDate = 'relationship.startDate';

class RelationshipNotifier extends StateNotifier<AppRelationship> {
  RelationshipNotifier(this._prefsFuture) : super(const AppRelationship()) {
    _load();
  }

  final Future<SharedPreferences> _prefsFuture;

  Future<void> _load() async {
    final prefs = await _prefsFuture;

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
    final prefs = await _prefsFuture;
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
    if (type.allowsThirdMember && updatedNames.length < 3) {
      updatedNames.add('');
    }
    state = AppRelationship(
      partnerNames: updatedNames,
      type: type,
      startDate: state.startDate,
    );
    final prefs = await _prefsFuture;
    await prefs.setString(_kType, type.name);
    await _persistNames();
  }

  Future<void> setStartDate(DateTime? date) async {
    state = AppRelationship(
      partnerNames: state.partnerNames,
      type: state.type,
      startDate: date,
    );
    final prefs = await _prefsFuture;
    if (date == null) {
      await prefs.remove(_kStartDate);
    } else {
      await prefs.setString(_kStartDate, date.toIso8601String());
    }
  }

  Future<void> clear() async {
    state = const AppRelationship();
    final prefs = await _prefsFuture;
    await prefs.remove(_kPartnerNames);
    await prefs.remove(_kType);
    await prefs.remove(_kStartDate);
  }
}

/// Provider con tipo explícito no-null.
final StateNotifierProvider<RelationshipNotifier, AppRelationship>
    relationshipProvider =
    StateNotifierProvider<RelationshipNotifier, AppRelationship>(
  (ref) => RelationshipNotifier(ref.read(prefsProvider.future)),
);