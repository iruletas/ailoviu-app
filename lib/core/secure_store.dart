import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Acceso a datos privados persistidos localmente (diario, cartas,
/// estados privados, etc.).
///
/// Respaldado por [FlutterSecureStorage]: en Android, valores
/// cifrados con una clave del Keystore del sistema. La API es
/// asíncrona (a diferencia de SharedPreferences).
///
/// Todas las claves llevan el prefijo `secure.` para no mezclarse con
/// las de [KeyStore] (claves criptográficas, PIN, config de sync).
///
/// Nota: no es para datos grandes (fotos, listas largas). Para eso,
/// archivos cifrados con una clave guardada aquí.
class SecureStore {
  SecureStore(this._storage);

  final FlutterSecureStorage _storage;

  static const String _prefix = 'secure.';

  String _key(String key) => '$_prefix$key';

  Future<String?> getString(String key) => _storage.read(key: _key(key));

  Future<void> setString(String key, String value) =>
      _storage.write(key: _key(key), value: value);

  Future<int?> getInt(String key) async {
    final raw = await getString(key);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> setInt(String key, int value) =>
      setString(key, value.toString());

  Future<bool?> getBool(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;
    return raw == 'true';
  }

  Future<void> setBool(String key, bool value) =>
      setString(key, value.toString());

  Future<List<String>?> getStringList(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return null;
    }
  }

  Future<void> setStringList(String key, List<String> value) =>
      setString(key, jsonEncode(value));

  Future<Map<String, dynamic>?> getJson(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      setString(key, jsonEncode(value));

  Future<void> remove(String key) => _storage.delete(key: _key(key));

  /// Claves actualmente persistidas (sin el prefijo `secure.`).
  Future<Set<String>> keys() async {
    final all = await _storage.readAll();
    return all.keys
        .where((k) => k.startsWith(_prefix))
        .map((k) => k.substring(_prefix.length))
        .toSet();
  }

  /// Borra solo los datos privados (prefijo `secure.`). No toca las
  /// claves de [KeyStore]. Útil para "restablecer todo".
  Future<void> clearAll() async {
    for (final key in await keys()) {
      await remove(key);
    }
  }
}
