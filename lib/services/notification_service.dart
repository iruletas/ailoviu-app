import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio de notificaciones.
///
/// - Inicializa `flutter_local_notifications` con el canal por
///   defecto.
/// - Muestra la notificación local cuando llega un sobre (ya
///   descifrado). La usa tanto la app como el servicio en segundo
///   plano (otro aislado), por eso el id de cada notificación se
///   deriva del id del sobre: si ambos la muestran, la segunda
///   REEMPLAZA a la primera en vez de duplicarla.
/// - El push de FCM no lleva contenido: solo la referencia al sobre.
class NotificationService {
  NotificationService();

  final _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'ailoviu_messages';
  static const _channelName = 'Mensajes de Ailoviu';
  static const _channelDescription =
      'Notificaciones de mensajes, estados y zumbidos';

  /// Id de notificación estable (FNV-1a 32 bits) a partir de un texto,
  /// p. ej. el id de un sobre. Igual en cualquier aislado y arranque.
  static int stableId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  /// [requestPermission] debe ser `false` fuera de la app (servicio en
  /// segundo plano): ahí no hay Activity para mostrar el diálogo.
  Future<void> initialize({bool requestPermission = true}) async {
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

    if (requestPermission) {
      await androidPlugin?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Muestra una notificación local con el contenido ya descifrado.
  ///
  /// Con [id] repetido, reemplaza la notificación anterior sin volver
  /// a sonar. En la pantalla de bloqueo oculta el contenido.
  Future<void> show({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    await _local.show(
      id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          onlyAlertOnce: true,
          visibility: NotificationVisibility.private,
        ),
      ),
      payload: payload,
    );
  }

  /// Configura el handler de FCM en foreground.
  ///
  /// (Sin uso mientras no haya Cloud Function que mande push; la
  /// entrega con la app cerrada la hace el servicio en primer plano.)
  Future<void> setupFcmHandlers({
    required void Function(RemoteMessage) onForeground,
  }) async {
    FirebaseMessaging.onMessage.listen(onForeground);
  }

  Future<void> cancel(int id) => _local.cancel(id);

  Future<void> cancelAll() => _local.cancelAll();
}
