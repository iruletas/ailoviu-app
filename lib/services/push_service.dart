import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Servicio de push FCM.
///
/// - Obtiene el token FCM del dispositivo.
/// - Lo registra en Firebase Realtime Database en
///   `tokens/{deviceId}`.
/// - El remitente lee ese token y manda push al destinatario cuando
///   escribe un sobre en su inbox.
///
/// **Nota sobre envío de push:** FCM no permite que un cliente
/// mande push a otro cliente directamente (por seguridad). El envío
/// requiere una Cloud Function o un servidor. Eso se resuelve en el
/// bloque de onboarding:
///   - Opción A: Cloud Function que escucha `inbox/{to}/messages`
///     y manda push al token del destinatario. Requiere desplegar
///     la función (una vez por pareja).
///   - Opción B: foreground service que mantiene la conexión viva,
///     y la notificación se muestra desde el propio servicio.
///     Requiere activación manual por el usuario.
///
/// Este servicio solo registra el token. El envío se implementa en
/// el bloque de onboarding.
class PushService {
  PushService();

  final _messaging = FirebaseMessaging.instance;

  Future<String?> getToken() => _messaging.getToken();

  Future<void> registerToken({
    required FirebaseDatabase db,
    required String deviceId,
  }) async {
    final token = await getToken();
    if (token == null) return;
    await db.ref('tokens/$deviceId').set({
      'token': token,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<String?> getPeerToken({
    required FirebaseDatabase db,
    required String peerDeviceId,
  }) async {
    final snapshot = await db.ref('tokens/$peerDeviceId').get();
    if (!snapshot.exists) return null;
    final raw = snapshot.value;
    if (raw is! Map) return null;
    return raw['token'] as String?;
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}