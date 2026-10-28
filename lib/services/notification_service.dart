import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio de notificaciones.
///
/// - Inicializa `flutter_local_notifications` con el canal por
///   defecto.
/// - Escucha mensajes FCM en foreground y muestra la notificación
///   local cuando llega un sobre.
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

  /// Configura el handler de FCM en foreground.
  ///
  /// El handler de background (cuando la app está cerrada) requiere
  /// un `@pragma('vm:entry-point')` en una función top-level, y se
  /// implementa en el bloque de onboarding. Aquí solo cubrimos
  /// foreground: cuando la app está abierta, FCM no muestra
  /// notificación automáticamente, así que la mostramos nosotros
  /// después de descifrar.
  Future<void> setupFcmHandlers({
    required void Function(RemoteMessage) onForeground,
  }) async {
    FirebaseMessaging.onMessage.listen(onForeground);
  }

  Future<void> cancelAll() => _local.cancelAll();
}