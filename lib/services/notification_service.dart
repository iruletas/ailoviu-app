import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio de notificaciones.
///
/// - Inicializa `flutter_local_notifications` con el canal por
///   defecto.
/// - Escucha mensajes FCM (foreground y background) y muestra la
///   notificación local cuando llega un sobre.
/// - El push de FCM no lleva contenido: solo la referencia al sobre.
///   El contenido se lee cifrado de Firebase, se descifra, y se
///   muestra.
class NotificationService {
  NotificationService();

  final _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'ailoviu_messages';
  static const _channelName = 'Mensajes de Ailoviu';
  static const _channelDescription =
      'Notificaciones de mensajes, estados y zumbidos';

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _local.initialize(initSettings);

    // Crear canal de Android.
    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
      ),
    );

    // Pedir permiso de notificaciones (Android 13+).
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Muestra una notificación local con el contenido ya descifrado.
  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }

  /// Configura los handlers de FCM.
  Future<void> setupFcmHandlers({
    required void Function(RemoteMessage) onForeground,
  }) async {
    // Foreground: FCM no muestra notificación automáticamente. La
    // mostramos nosotros después de descifrar.
    FirebaseMessaging.onMessage.listen(onForeground);

    // Background: Android muestra la notificación automáticamente si
    // el mensaje tiene `notification` configurado. Si no, no se
    // muestra. En nuestro caso, el push solo lleva `data`, así que
    // la notificación se muestra cuando la app se abre.
    // Para mostrar notificación en background, necesitaríamos un
    // handler aislado (background message handler) que escribe en
    // flutter_local_notifications. Lo dejamos para la tanda 3c
    // (Double Ratchet) o para el bloque de UI.
  }

  Future<void> cancelAll() => _local.cancelAll();
}