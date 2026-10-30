import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/key_store.dart';
import 'sync_providers.dart'; // Para keyStoreProvider

class CartoKeyNotifier extends StateNotifier<String> {
  CartoKeyNotifier(this._keyStore) : super('') {
    _load();
  }

  final KeyStore _keyStore;

  Future<void> _load() async {
    try {
      final key = await _keyStore.getCartoKey();
      if (key != null) state = key;
    } catch (_) {
      // Ignorar si falla el Keystore
    }
  }

  Future<void> setKey(String key) async {
    final trimmed = key.trim();
    state = trimmed;
    try {
      if (trimmed.isEmpty) {
        await _keyStore.clearCartoKey();
      } else {
        await _keyStore.setCartoKey(trimmed);
      }
    } catch (_) {
      // Fallo al escribir en Keystore
    }
  }
}

final cartoKeyProvider = StateNotifierProvider<CartoKeyNotifier, String>(
  (ref) => CartoKeyNotifier(ref.watch(keyStoreProvider)),
);