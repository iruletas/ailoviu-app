import 'package:uuid/uuid.dart';

import 'key_store.dart';

/// Servicio de identidad del dispositivo.
///
/// - Genera un UUID la primera vez que se abre la app.
/// - Lo persiste en [KeyStore] (Keystore Android, cifrado en reposo).
/// - Lo devuelve en futuras aperturas.
///
/// **No depende de SyncService.** El deviceId existe aunque nunca
/// haya pareja emparejada.
class DeviceIdentityService {
  DeviceIdentityService({KeyStore? keyStore, Uuid? uuid})
      : _keyStore = keyStore ?? KeyStore(),
        _uuid = uuid ?? const Uuid();

  final KeyStore _keyStore;
  final Uuid _uuid;

  /// Obtiene el deviceId, creándolo si no existe.
  ///
  /// Es idempotente: llamarlo N veces seguidas devuelve el mismo valor
  /// (la primera vez lo crea, las siguientes lo leen del Keystore).
  Future<String> getOrCreate() async {
    final existing = await _keyStore.getDeviceId();
    if (existing != null && existing.isNotEmpty) return existing;

    final fresh = _uuid.v4();
    await _keyStore.setDeviceId(fresh);
    return fresh;
  }

  /// `true` si el deviceId ya está creado.
  Future<bool> hasDeviceId() async {
    final id = await _keyStore.getDeviceId();
    return id != null && id.isNotEmpty;
  }
}