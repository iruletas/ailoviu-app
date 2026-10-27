/// Claves de persistencia para autenticación.
///
/// Prefijo `auth.` para no mezclarse con `settings.`, `relationship.`
/// ni `secure.`.
class AuthKeys {
  AuthKeys._();

  static const String appLockEnabled = 'auth.appLockEnabled';
  static const String appLockTimeoutMs = 'auth.appLockTimeoutMs';
  static const String systemAuthAvailable = 'auth.systemAuthAvailable';
  static const String appPinHash = 'auth.appPinHash';
  static const String appPinSalt = 'auth.appPinSalt';
  static const String featureLockPrefix = 'auth.featureLock.';
}

/// Features privadas conocidas por la app.
///
/// Agregar aquí cuando una feature nueva requiera bloqueo opcional.
/// El id se usa como sufijo en la clave de persistencia y como
/// identificador en `AuthSession.unlockedFeatures`.
class PrivateFeatures {
  PrivateFeatures._();

  static const String diary = 'diary';
  static const String letters = 'letters';
  static const String privateStates = 'privateStates';
  static const String gallery = 'gallery';
  static const String memories = 'memories';

  /// Todas las features privadas actualmente soportadas.
  static const List<String> all = [
    diary,
    letters,
    privateStates,
    gallery,
    memories,
  ];

  /// Label humano en español, para UI de Ajustes.
  static String labelOf(String featureId) {
    switch (featureId) {
      case diary:
        return 'Diario';
      case letters:
        return 'Cartas';
      case privateStates:
        return 'Estados privados';
      case gallery:
        return 'Galería';
      case memories:
        return 'Recuerdos';
      default:
        return featureId;
    }
  }
}