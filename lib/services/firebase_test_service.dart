import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'key_store.dart';
import 'transport_config.dart';

/// Resultado de un intento de probar la conexión a Firebase.
///
/// Cada valor está pensado para que la UI muestre un mensaje accionable,
/// no un "error" genérico. El enum define QUÉ falló; el `message` del
/// resultado dice CÓMO arreglarlo.
enum FirebaseTestResult {
  /// Todo bien: config válida, auth anónima, reglas permiten leer y
  /// escribir en el ping.
  success,

  /// No hay `transport.config` guardado en Keystore. El usuario no ha
  /// pegado el `google-services.json`.
  missingConfig,

  /// El JSON que pegó no parsea o le faltan campos. Firebase rechazó
  /// `initializeApp`.
  configError,

  /// `initializeApp` ok, pero `signInAnonymously` falló. Lo más común:
  /// el proveedor "Anónimo" no está habilitado en Firebase Console →
  /// Authentication → Sign-in method.
  authError,

  /// Escribir en `invites/_ping` falló con `permission_denied`. Las
  /// reglas de Realtime Database no están publicadas o están mal.
  permissionDenied,

  /// Escribir falló por timeout o error de red. Revisa la conexión a
  /// internet del celular.
  networkError,

  /// La escritura fue aceptada, pero leer de vuelta no devolvió el
  /// valor. Muy raro: significa que las reglas permiten escribir pero
  /// no leer.
  readBackError,

  /// Cualquier otro error no clasificado. El `message` trae el detalle.
  unknown,
}

/// Resultado completo de un test, con mensaje humano y detalle técnico
/// opcional para debug.
class FirebaseTestReport {
  final FirebaseTestResult result;

  /// Mensaje listo para mostrar en UI. Español, accionable, sin jerga.
  final String message;

  /// Detalle técnico del error (stack, código). Solo para el log
  /// interno o para un tooltip de debug. `null` si no aplica.
  final String? technicalDetail;

  /// Cuándo se corrió el test.
  final DateTime testedAt;

  const FirebaseTestReport({
    required this.result,
    required this.message,
    required this.testedAt,
    this.technicalDetail,
  });

  bool get isSuccess => result == FirebaseTestResult.success;

  static FirebaseTestReport fail({
    required FirebaseTestResult result,
    required String message,
    String? technicalDetail,
  }) {
    return FirebaseTestReport(
      result: result,
      message: message,
      technicalDetail: technicalDetail,
      testedAt: DateTime.now(),
    );
  }

  static FirebaseTestReport ok() {
    return FirebaseTestReport(
      result: FirebaseTestResult.success,
      message:
          'Todo listo. A partir de aquí, lo que compartan es solo de '
          'ustedes.',
      testedAt: DateTime.now(),
    );
  }
}

/// Servicio que prueba la conexión a Firebase de punta a punta.
///
/// Flujo:
/// 1. Lee `transport.config` de Keystore.
/// 2. `Firebase.initializeApp` con esa config (si no estaba inicializado).
/// 3. `signInAnonymously`.
/// 4. Escribe en `invites/_ping/{deviceId}`.
/// 5. Lee de vuelta el valor escrito.
/// 6. Borra el ping.
///
/// Cada paso que falla devuelve un `FirebaseTestResult` distinto, con un
/// mensaje que dice exactamente qué revisar en Firebase Console.
///
/// **No lanza excepciones.** Siempre devuelve un `FirebaseTestReport`.
class FirebaseTestService {
  FirebaseTestService({required KeyStore keyStore}) : _keyStore = keyStore;

  final KeyStore _keyStore;

  static const Duration _writeTimeout = Duration(seconds: 10);
  static const Duration _readTimeout = Duration(seconds: 10);

  Future<FirebaseTestReport> testConnection() async {
    // ── 1. Config guardada ─────────────────────────────────────────
    final rawConfig = await _keyStore.getTransportConfig();
    if (rawConfig == null) {
      return FirebaseTestReport.fail(
        result: FirebaseTestResult.missingConfig,
        message:
            'Aún no has pegado el google-services.json. Vuelve al paso '
            'anterior y pégalo completo.',
      );
    }

    final TransportConfig config;
    try {
      config = await TransportConfig.load(_keyStore);
    } catch (e) {
      return FirebaseTestReport.fail(
        result: FirebaseTestResult.configError,
        message:
            'El JSON que pegaste tiene un problema. Revisa que esté '
            'completo y que sea exactamente el archivo que Firebase te '
            'descargó, sin cortar líneas.',
        technicalDetail: e.toString(),
      );
    }

    if (config is! FirebaseTransportConfig) {
      return FirebaseTestReport.fail(
        result: FirebaseTestResult.configError,
        message:
            'La configuración guardada no es de Firebase. Vuelve a pegar '
            'el archivo desde el paso anterior.',
      );
    }

    // ── 2. Inicializar Firebase ────────────────────────────────────
    final deviceId = await _keyStore.getDeviceId() ?? 'unknown';
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: config.apiKey,
            appId: config.appId,
            messagingSenderId: config.messagingSenderId,
            projectId: config.projectId,
            databaseURL: config.databaseUrl,
            storageBucket: config.storageBucket,
          ),
        );
      }
    } catch (e) {
      return FirebaseTestReport.fail(
        result: FirebaseTestResult.configError,
        message:
            'Firebase no pudo arrancar con esta configuración. Asegúrate '
            'de que el archivo es de un proyecto que existe y que no lo '
            'modificaste al copiarlo.',
        technicalDetail: e.toString(),
      );
    }

    // ── 3. Auth anónima ────────────────────────────────────────────
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
    } on FirebaseAuthException catch (e) {
      final code = e.code;
      if (code == 'admin-restricted-operation' ||
          code == 'operation-not-allowed') {
        return FirebaseTestReport.fail(
          result: FirebaseTestResult.authError,
          message:
              'Falta habilitar la autenticación anónima. Ve a Firebase '
              'Console → Authentication → Comenzar → Anónimo → Habilitar, '
              'y vuelve a probar.',
          technicalDetail: code,
        );
      }
      return FirebaseTestReport.fail(
        result: FirebaseTestResult.authError,
        message:
            'No se pudo iniciar sesión anónima en Firebase. Revisa que '
            'la autenticación esté habilitada y que tu conexión funcione.',
        technicalDetail: code,
      );
    } catch (e) {
      return FirebaseTestReport.fail(
        result: FirebaseTestResult.authError,
        message:
            'La autenticación con Firebase falló. Revisa tu conexión y '
            'vuelve a intentarlo.',
        technicalDetail: e.toString(),
      );
    }

    // ── 4. Escritura en el ping ────────────────────────────────────
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: config.databaseUrl,
    );
    final pingRef = db.ref('invites/_ping/$deviceId');
    final payload = {
      'ts': DateTime.now().millisecondsSinceEpoch,
      'probe': true,
    };

    try {
      await pingRef.set(payload).timeout(_writeTimeout);
    } on TimeoutException {
      return FirebaseTestReport.fail(
        result: FirebaseTestResult.networkError,
        message:
            'La escritura en Firebase tardó demasiado. Revisa tu conexión '
            'a internet y vuelve a intentarlo.',
      );
    } on FirebaseException catch (e) {
      // En Realtime Database los errores llegan como FirebaseException
      // (de firebase_core). El código útil está en `e.code` o, si no,
      // en el mensaje.
      final code = e.code ?? '';
      final detail = '$code: ${e.message ?? e.toString()}';
      final looksLikePermission = code.contains('permission-denied') ||
          code.contains('permission_denied') ||
          detail.contains('permission_denied') ||
          detail.contains('permission-denied');
      if (looksLikePermission) {
        return FirebaseTestReport.fail(
          result: FirebaseTestResult.permissionDenied,
          message:
              'Las reglas de la base de datos no permiten escribir aún. '
              'Ve a Firebase Console → Realtime Database → Reglas, pega '
              'el texto del paso anterior y toca "Publicar".',
          technicalDetail: detail,
        );
      }
      return FirebaseTestReport.fail(
        result: FirebaseTestResult.unknown,
        message:
            'No se pudo escribir en Firebase. Revisa que la base de datos '
            'esté creada y que el archivo sea del proyecto correcto.',
        technicalDetail: detail,
      );
    } catch (e) {
      return FirebaseTestReport.fail(
        result: FirebaseTestResult.unknown,
        message:
            'Algo falló al escribir en Firebase. Vuelve a intentarlo; si '
            'persiste, revisa la configuración en la consola.',
        technicalDetail: e.toString(),
      );
    }

    // ── 5. Lectura de vuelta ──────────────────────────────────────
    try {
      final snapshot = await pingRef.get().timeout(_readTimeout);
      if (!snapshot.exists) {
        return FirebaseTestReport.fail(
          result: FirebaseTestResult.readBackError,
          message:
              'La escritura fue aceptada pero la lectura no devolvió '
              'nada. Revisa que las reglas permitan leer y escribir en '
              '"invites".',
        );
      }
    } on TimeoutException {
      return FirebaseTestReport.fail(
        result: FirebaseTestResult.networkError,
        message:
            'La lectura de confirmación tardó demasiado. Revisa tu '
            'conexión y vuelve a intentarlo.',
      );
    } catch (e) {
      return FirebaseTestReport.fail(
        result: FirebaseTestResult.readBackError,
        message:
            'La escritura funcionó pero la lectura de vuelta falló. '
            'Revisa que las reglas permitan leer en "invites".',
        technicalDetail: e.toString(),
      );
    }

    // ── 6. Limpieza del ping ──────────────────────────────────────
    // No esperamos ni reportamos error si falla: es un ping, no un dato
    // del usuario. Si por algo quedó huérfano, se limpia solo en la
    // próxima prueba.
    unawaited(
      pingRef.remove().catchError((Object _) {}),
    );

    return FirebaseTestReport.ok();
  }
}