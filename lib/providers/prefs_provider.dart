import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Instancia única de [SharedPreferences] para toda la app.
final prefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// Acceso a datos privados persistidos localmente.
///
/// Usa el prefijo `secure.` sobre [SharedPreferences] para aislar los
/// datos sensibles (diario, cartas, estados privados, etc.) del resto
/// de las preferencias de la app. La API es centralizada a propósito:
/// si en el futuro se requiere cifrado real, se reemplaza el backend
/// por `flutter_secure_storage` sin tocar a los consumidores.
///
/// Nota: [SharedPreferences] no está cifrado. Esta capa NO es
/// criptografía, es aislamiento de namespace + un punto único de
/// migración futura.
class SecureStore {
  SecureStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _prefix = 'secure.';

  String _key(String key) => '$_prefix$key';

  String? getString(String key) => _prefs.getString(_key(key));

  Future<bool> setString(String key, String value) =>
      _prefs.setString(_key(key), value);

  List<String>? getStringList(String key) => _prefs.getStringList(_key(key));

  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(_key(key), value);

  int? getInt(String key) => _prefs.getInt(_key(key));

  Future<bool> setInt(String key, int value) => _prefs.setInt(_key(key), value);

  bool? getBool(String key) => _prefs.getBool(_key(key));

  Future<bool> setBool(String key, bool value) =>
      _prefs.setBool(_key(key), value);

  Future<bool> remove(String key) => _prefs.remove(_key(key));

  /// Claves actualmente persistidas con el prefijo `secure.`.
  Set<String> keysWithPrefix() => _prefs
      .getKeys()
      .where((k) => k.startsWith(_prefix))
      .toSet();

  /// Borra todos los datos privados. Útil para "restablecer todo".
  Future<void> clearAll() async {
    for (final key in keysWithPrefix()) {
      await _prefs.remove(key);
    }
  }
}

/// [SecureStore] listo para usar, una vez que `SharedPreferences`
/// terminó de cargar.
final secureStoreProvider = FutureProvider<SecureStore>((ref) async {
  final prefs = await ref.watch(prefsProvider.future);
  return SecureStore(prefs);
});