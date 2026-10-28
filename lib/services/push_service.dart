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
/// El push **no lleva contenido**. Solo lleva `{type, envelopeId}`.
/// El receptor lee el sobre cifrado de Firebase, lo descifra, y
/// muestra la notificación local.
class PushService {
  PushService();

  final _messaging = FirebaseMessaging.instance;

  /// Obtiene el token FCM del dispositivo.
  Future<String?> getToken() => _messaging.getToken();

  /// Registra el token en Firebase Realtime Database.
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

  /// Lee el token FCM del otro dispositivo.
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

  /// Escucha cambios en el token. Útil cuando FCM rota el token.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}