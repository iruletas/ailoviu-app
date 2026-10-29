import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/secure_store.dart';

/// Instancia única de [SharedPreferences] para toda la app.
///
/// Solo para preferencias no sensibles (tema, ajustes, flags).
/// Todo lo sensible va en [SecureStore] o en `KeyStore`.
final prefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// [SecureStore] listo para usar (datos privados en Keystore).
///
/// Usa las mismas opciones que `KeyStore`, así que ambos escriben en
/// el mismo almacén cifrado, con prefijos distintos.
final secureStoreProvider = Provider<SecureStore>((ref) {
  return SecureStore(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  );
});
