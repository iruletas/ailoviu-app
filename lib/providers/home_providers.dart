import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/secure_store.dart';
import '../models/home_models.dart';
import '../models/sync_models.dart';
import 'prefs_provider.dart';
import 'sync_providers.dart';

// ═══════════════════════════════════════════════════════════════════════
// Claves de persistencia (prefijo home.)
// ═══════════════════════════════════════════════════════════════════════

class _Keys {
  _Keys._();
  static const myStatus = 'home.myStatus';
  static const partnerStatus = 'home.partnerStatus';
  static const myLocation = 'home.myLocation';
  static const partnerLocation = 'home.partnerLocation';
  static const buzz = 'home.buzz';
  static const distance = 'home.distance';
}

// ═══════════════════════════════════════════════════════════════════════
// Status (estado de hoy)
// ═══════════════════════════════════════════════════════════════════════

class StatusNotifier extends StateNotifier<PartnerStatus?> {
  StatusNotifier(this._store) : super(null) {
    _load();
  }

  final SecureStore _store;

  Future<void> _load() async {
    final json = await _store.getJson(_Keys.myStatus);
    if (json == null) return;
    try {
      final status = PartnerStatus.fromJson(json);
      if (!status.isExpired()) {
        state = status;
      } else {
        await _store.remove(_Keys.myStatus);
      }
    } catch (_) {
      await _store.remove(_Keys.myStatus);
    }
  }

  Future<void> setStatus({
    required String text,
    String? emoji,
    required String authorDeviceId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      await clear();
      return;
    }
    final status = PartnerStatus(
      authorDeviceId: authorDeviceId,
      text: trimmed,
      emoji: emoji,
      writtenAt: DateTime.now(),
    );
    state = status;
    await _store.setJson(_Keys.myStatus, status.toJson());
  }

  Future<void> clear() async {
    state = null;
    await _store.remove(_Keys.myStatus);
  }
}

final myStatusProvider =
    StateNotifierProvider<StatusNotifier, PartnerStatus?>(
  (ref) => StatusNotifier(ref.read(secureStoreProvider)),
);

// ═══════════════════════════════════════════════════════════════════════
// Partner status (lo que llega por sync)
// ═══════════════════════════════════════════════════════════════════════

class PartnerStatusNotifier extends StateNotifier<PartnerStatus?> {
  PartnerStatusNotifier(this._store) : super(null) {
    _load();
  }

  final SecureStore _store;

  Future<void> _load() async {
    final json = await _store.getJson(_Keys.partnerStatus);
    if (json == null) return;
    try {
      final status = PartnerStatus.fromJson(json);
      if (!status.isExpired()) {
        state = status;
      } else {
        await _store.remove(_Keys.partnerStatus);
      }
    } catch (_) {
      await _store.remove(_Keys.partnerStatus);
    }
  }

  Future<void> save(PartnerStatus status) async {
    state = status;
    await _store.setJson(_Keys.partnerStatus, status.toJson());
  }

  Future<void> clear() async {
    state = null;
    await _store.remove(_Keys.partnerStatus);
  }
}

final partnerStatusProvider =
    StateNotifierProvider<PartnerStatusNotifier, PartnerStatus?>(
  (ref) => PartnerStatusNotifier(ref.read(secureStoreProvider)),
);

// ═══════════════════════════════════════════════════════════════════════
// Locations
// ═══════════════════════════════════════════════════════════════════════

class LocationsNotifier
    extends StateNotifier<({PartnerLocation? me, PartnerLocation? partner})> {
  LocationsNotifier(this._store) : super((me: null, partner: null)) {
    _load();
  }

  final SecureStore _store;

  Future<void> _load() async {
    final myJson = await _store.getJson(_Keys.myLocation);
    final partnerJson = await _store.getJson(_Keys.partnerLocation);
    state = (
      me: myJson != null ? _tryParseLocation(myJson) : null,
      partner: partnerJson != null ? _tryParseLocation(partnerJson) : null,
    );
  }

  PartnerLocation? _tryParseLocation(Map<String, dynamic> json) {
    try {
      return PartnerLocation.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMine(PartnerLocation loc) async {
    state = (me: loc, partner: state.partner);
    await _store.setJson(_Keys.myLocation, loc.toJson());
  }

  Future<void> savePartner(PartnerLocation loc) async {
    state = (me: state.me, partner: loc);
    await _store.setJson(_Keys.partnerLocation, loc.toJson());
  }
}

final locationsProvider = StateNotifierProvider<LocationsNotifier,
    ({PartnerLocation? me, PartnerLocation? partner})>(
  (ref) => LocationsNotifier(ref.read(secureStoreProvider)),
);

// ═══════════════════════════════════════════════════════════════════════
// Buzz
// ═══════════════════════════════════════════════════════════════════════

class BuzzNotifier extends StateNotifier<BuzzState> {
  BuzzNotifier(this._store)
      : super(BuzzState(todayDate: DateTime.now())) {
    _load();
  }

  final SecureStore _store;

  Future<void> _load() async {
    final json = await _store.getJson(_Keys.buzz);
    if (json == null) return;
    try {
      final saved = BuzzState.fromJson(json);
      state = saved.resetIfNewDay(DateTime.now());
    } catch (_) {
      // Ignorar.
    }
  }

  Future<bool> tryBuzz({required WidgetRef ref}) async {
    final now = DateTime.now();
    final current = state.resetIfNewDay(now);
    if (!current.canBuzz(now: now)) {
      state = current;
      return false;
    }

    // TODO: cuando la UI de sync esté, aquí va:
    // await ref.read(syncServiceProvider.future).enqueue(
    //   type: SyncType.message,
    //   payload: {'intent': 'buzz', 'sentAt': now.toIso8601String()},
    // );

    final updated = current.markSent(now);
    state = updated;
    await _store.setJson(_Keys.buzz, updated.toJson());
    return true;
  }
}

final buzzProvider = StateNotifierProvider<BuzzNotifier, BuzzState>(
  (ref) => BuzzNotifier(ref.read(secureStoreProvider)),
);

// ═══════════════════════════════════════════════════════════════════════
// Distance config
// ═══════════════════════════════════════════════════════════════════════

class DistanceNotifier extends StateNotifier<DistanceConfig> {
  DistanceNotifier(this._store) : super(const DistanceConfig()) {
    _load();
  }

  final SecureStore _store;

  Future<void> _load() async {
    final json = await _store.getJson(_Keys.distance);
    if (json == null) return;
    try {
      state = DistanceConfig.fromJson(json);
    } catch (_) {
      // Ignorar.
    }
  }

  Future<void> setFixedKm(int? km) async {
    state = state.copyWith(fixedKm: km, clearFixedKm: km == null);
    await _save();
  }

  Future<void> setLastSeenAt(DateTime? dt) async {
    state = state.copyWith(
      lastSeenAt: dt,
      clearLastSeenAt: dt == null,
    );
    await _save();
  }

  Future<void> _save() async {
    if (!state.hasAny) {
      await _store.remove(_Keys.distance);
    } else {
      await _store.setJson(_Keys.distance, state.toJson());
    }
  }
}

final distanceProvider = StateNotifierProvider<DistanceNotifier, DistanceConfig>(
  (ref) => DistanceNotifier(ref.read(secureStoreProvider)),
);

// ═══════════════════════════════════════════════════════════════════════
// Helpers para sync entrante
// ═══════════════════════════════════════════════════════════════════════

/// Procesa un payload de sync entrante relacionado con home.
/// Llamar desde un listener de `syncEventsProvider`.
Future<void> handleHomeSyncPayload({
  required WidgetRef ref,
  required SyncType type,
  required Map<String, dynamic> data,
}) async {
  if (type != SyncType.state) return;

  final subtype = data['subtype'] as String?;
  if (subtype == null) return;

  try {
    switch (subtype) {
      case 'status':
        final status = PartnerStatus.fromJson(
          Map<String, dynamic>.from(data['status'] as Map),
        );
        if (!status.isExpired()) {
          await ref.read(partnerStatusProvider.notifier).save(status);
        }
        break;
      case 'location':
        final loc = PartnerLocation.fromJson(
          Map<String, dynamic>.from(data['location'] as Map),
        );
        await ref.read(locationsProvider.notifier).savePartner(loc);
        break;
    }
  } catch (_) {
    // Payload malformado: ignorar.
  }
}

/// Serializa el estado local para mandarlo por sync.
Map<String, dynamic> statusToSyncPayload(PartnerStatus status) => {
      'subtype': 'status',
      'status': status.toJson(),
    };

/// Serializa la ubicación local para mandarlo por sync.
Map<String, dynamic> locationToSyncPayload(PartnerLocation loc) => {
      'subtype': 'location',
      'location': loc.toJson(),
    };