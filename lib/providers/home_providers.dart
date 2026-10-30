import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/secure_store.dart';
import '../models/home_models.dart';
import '../models/sync_models.dart';
import '../services/device_identity_service.dart';
import 'prefs_provider.dart';
import 'sync_providers.dart';

// ══════════════════════════════════════════════════════════════════════
// Claves de persistencia (prefijo home.)
// ══════════════════════════════════════════════════════════════════════

class _Keys {
  _Keys._();
  static const myStatus = 'home.myStatus';
  static const statusesPrefix = 'home.status.';
  static const locations = 'home.locations';
  static const buzz = 'home.buzz';
  static const distance = 'home.distance';
}

// ══════════════════════════════════════════════════════════════════════
// deviceId local
// ══════════════════════════════════════════════════════════════════════

final deviceIdentityServiceProvider = Provider<DeviceIdentityService>(
  (ref) => DeviceIdentityService(keyStore: ref.watch(keyStoreProvider)),
);

final myDeviceIdProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(deviceIdentityServiceProvider);
  return service.getOrCreate();
});

// ══════════════════════════════════════════════════════════════════════
// Statuses
// ══════════════════════════════════════════════════════════════════════

class MyStatusNotifier extends StateNotifier<PartnerStatus?> {
  MyStatusNotifier(this._ref, this._store) : super(null) {
    _load();
  }

  final Ref _ref;
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
    _tryEnqueue(statusToSyncPayload(status));
  }

  Future<void> clear() async {
    state = null;
    await _store.remove(_Keys.myStatus);
  }

  void _tryEnqueue(Map<String, dynamic> payload) {
    _ref.read(syncServiceProvider.future).then((service) {
      service.enqueue(type: SyncType.state, payload: payload);
    }).catchError((_) {});
  }
}

final myStatusProvider =
    StateNotifierProvider<MyStatusNotifier, PartnerStatus?>(
  (ref) => MyStatusNotifier(ref, ref.read(secureStoreProvider)),
);

class StatusesNotifier extends StateNotifier<Map<String, PartnerStatus>> {
  StatusesNotifier(this._store) : super(const {}) {
    _load();
  }

  final SecureStore _store;

  Future<void> _load() async {
    final keys = await _store.keys();
    final statusKeys = keys.where((k) => k.startsWith(_Keys.statusesPrefix));
    final loaded = <String, PartnerStatus>{};
    for (final k in statusKeys) {
      final deviceId = k.substring(_Keys.statusesPrefix.length);
      final json = await _store.getJson(k);
      if (json == null) continue;
      try {
        final status = PartnerStatus.fromJson(json);
        if (!status.isExpired()) {
          loaded[deviceId] = status;
        } else {
          await _store.remove(k);
        }
      } catch (_) {
        await _store.remove(k);
      }
    }
    state = loaded;
  }

  Future<void> save(PartnerStatus status) async {
    final updated = Map<String, PartnerStatus>.from(state);
    updated[status.authorDeviceId] = status;
    state = updated;
    await _store.setJson(
      '${_Keys.statusesPrefix}${status.authorDeviceId}',
      status.toJson(),
    );
  }

  Future<void> removeFor(String deviceId) async {
    final updated = Map<String, PartnerStatus>.from(state)..remove(deviceId);
    state = updated;
    await _store.remove('${_Keys.statusesPrefix}$deviceId');
  }
}

final statusesProvider =
    StateNotifierProvider<StatusesNotifier, Map<String, PartnerStatus>>(
  (ref) => StatusesNotifier(ref.read(secureStoreProvider)),
);

// ══════════════════════════════════════════════════════════════════════
// Locations
// ══════════════════════════════════════════════════════════════════════

class LocationsNotifier extends StateNotifier<LocationsSnapshot> {
  LocationsNotifier(this._ref, this._store, this._myDeviceId)
      : super(LocationsSnapshot(myDeviceId: _myDeviceId)) {
    _load();
  }

  final Ref _ref;
  final SecureStore _store;
  final String _myDeviceId;

  Future<void> _load() async {
    final json = await _store.getJson(_Keys.locations);
    if (json == null) return;
    try {
      final map = <String, PartnerLocation>{};
      for (final entry in json.entries) {
        final loc = PartnerLocation.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        map[entry.key] = loc;
      }
      state = LocationsSnapshot(all: map, myDeviceId: _myDeviceId);
    } catch (_) {
      await _store.remove(_Keys.locations);
    }
  }

  Future<void> saveMyLocation(PartnerLocation loc) async {
    final updated = Map<String, PartnerLocation>.from(state.all);
    updated[loc.deviceId] = loc;
    state = LocationsSnapshot(all: updated, myDeviceId: _myDeviceId);
    await _persist();
    _tryEnqueue(locationToSyncPayload(loc));
  }

  Future<void> saveOtherLocation(PartnerLocation loc) async {
    final updated = Map<String, PartnerLocation>.from(state.all);
    updated[loc.deviceId] = loc;
    state = LocationsSnapshot(all: updated, myDeviceId: _myDeviceId);
    await _persist();
  }

  Future<void> removeDevice(String deviceId) async {
    final updated = Map<String, PartnerLocation>.from(state.all)
      ..remove(deviceId);
    state = LocationsSnapshot(all: updated, myDeviceId: _myDeviceId);
    await _persist();
  }

  Future<void> _persist() async {
    final json = <String, dynamic>{
      for (final e in state.all.entries) e.key: e.value.toJson(),
    };
    await _store.setJson(_Keys.locations, json);
  }

  void _tryEnqueue(Map<String, dynamic> payload) {
    _ref.read(syncServiceProvider.future).then((service) {
      service.enqueue(type: SyncType.state, payload: payload);
    }).catchError((_) {});
  }
}

final locationsProvider =
    StateNotifierProvider<LocationsNotifier, LocationsSnapshot>((ref) {
  final myId = ref.watch(myDeviceIdProvider).valueOrNull ?? '';
  return LocationsNotifier(ref, ref.read(secureStoreProvider), myId);
});

// ══════════════════════════════════════════════════════════════════════
// Buzz
// ══════════════════════════════════════════════════════════════════════

class BuzzNotifier extends StateNotifier<BuzzState> {
  BuzzNotifier(this._ref, this._store)
      : super(BuzzState(todayDate: DateTime.now())) {
    _load();
  }

  final Ref _ref;
  final SecureStore _store;

  Future<void> _load() async {
    final json = await _store.getJson(_Keys.buzz);
    if (json == null) return;
    try {
      final saved = BuzzState.fromJson(json);
      state = saved.resetIfNewDay(DateTime.now());
    } catch (_) {}
  }

  Future<bool> tryBuzz() async {
    final now = DateTime.now();
    final current = state.resetIfNewDay(now);
    if (!current.canBuzz(now: now)) {
      state = current;
      return false;
    }

    final updated = current.markSent(now);
    state = updated;
    await _store.setJson(_Keys.buzz, updated.toJson());

    _ref.read(syncServiceProvider.future).then((service) {
      service.enqueue(
        type: SyncType.message,
        payload: {
          'intent': 'buzz',
          'sentAt': now.toIso8601String(),
          'preview': 'Te mandó un zumbido ⚡',
        },
      );
    }).catchError((_) {});

    return true;
  }
}

final buzzProvider = StateNotifierProvider<BuzzNotifier, BuzzState>(
  (ref) => BuzzNotifier(ref, ref.read(secureStoreProvider)),
);

// ══════════════════════════════════════════════════════════════════════
// Distance
// ══════════════════════════════════════════════════════════════════════

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
    } catch (_) {}
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

final distanceProvider =
    StateNotifierProvider<DistanceNotifier, DistanceConfig>(
  (ref) => DistanceNotifier(ref.read(secureStoreProvider)),
);

// ══════════════════════════════════════════════════════════════════════
// Sync entrante (N miembros)
// ══════════════════════════════════════════════════════════════════════

Future<void> handleHomeSyncPayload({
  required Ref ref,
  required SyncType type,
  required Map<String, dynamic> data,
}) async {
  if (type != SyncType.state) return;

  final subtype = data['subtype'] as String?;
  if (subtype == null) return;

  final myId = ref.read(myDeviceIdProvider).valueOrNull ?? '';

  try {
    switch (subtype) {
      case 'status':
        final status = PartnerStatus.fromJson(
          Map<String, dynamic>.from(data['status'] as Map),
        );
        if (status.authorDeviceId == myId) return;
        if (!status.isExpired()) {
          await ref.read(statusesProvider.notifier).save(status);
        }
        break;
      case 'location':
        final loc = PartnerLocation.fromJson(
          Map<String, dynamic>.from(data['location'] as Map),
        );
        if (loc.deviceId == myId) return;
        await ref.read(locationsProvider.notifier).saveOtherLocation(loc);
        break;
    }
  } catch (_) {}
}

Map<String, dynamic> statusToSyncPayload(PartnerStatus status) => {
      'subtype': 'status',
      'status': status.toJson(),
    };

Map<String, dynamic> locationToSyncPayload(PartnerLocation loc) => {
      'subtype': 'location',
      'location': loc.toJson(),
    };