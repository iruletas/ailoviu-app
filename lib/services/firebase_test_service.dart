import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'key_store.dart';
import 'transport_config.dart';

/// Resultado de un intento de probar la conexión a Firebase.
enum FirebaseTestResult {
  success,
  missingConfig,
  configError,
  authError,
  permissionDenied,
  networkError,
  readBackError,
  unknown,
}

class FirebaseTestReport {
  final FirebaseTestResult result;
  final String message;
  final String? technicalDetail;
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

class FirebaseTestService {
  FirebaseTestService({required KeyStore keyStore}) : _keyStore = keyStore;

  final KeyStore _keyStore;

  static const Duration _writeTimeout = Duration(seconds: 10);
  static const Duration _readTimeout = Duration(seconds: 10);

  Future<FirebaseTestReport> testConnection() async {
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

    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: config.databaseUrl,
    );
    
    // Escribimos directo en invites/_ping y agregamos un 'requests' vacío
    // para cumplir con la regla: newData.hasChild('requests').
    final pingRef = db.ref('invites/_ping');
    final payload = {
      'ts': DateTime.now().millisecondsSinceEpoch,
      'probe': true,
      'requests': <String, dynamic>{}, // Dummy para la regla de Firebase
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

    unawaited(
      pingRef.remove().catchError((Object _) {}),
    );

    return FirebaseTestReport.ok();
  }
}