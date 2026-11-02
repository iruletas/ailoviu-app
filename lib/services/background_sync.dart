import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sync_models.dart';
import 'crypto_service.dart';
import 'invite_service.dart';
import 'key_store.dart';
import 'notification_service.dart';
import 'sync_service.dart';
import 'transport_config.dart';

@pragma('vm:entry-point')
void startBackgroundSync() {
  FlutterForegroundTask.setTaskHandler(BackgroundSyncHandler());
}

class BackgroundSyncHandler extends TaskHandler {
  SyncService? _sync;
  NotificationService? _notifications;
  StreamSubscription<SyncStatus>? _statusSub;
  StreamSubscription<InviteRequest>? _inviteSub;
  bool _restarting = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    DartPluginRegistrant.ensureInitialized();
    await _startSync();
  }

  Future<void> _startSync() async {
    await _stopSync();
    final notifications = NotificationService();
    _notifications = notifications;
    final service = SyncService(
      keyStore: KeyStore(),
      crypto: CryptoService(),
      notifications: notifications,
      notifyOnly: true,
    );
    _sync = service;
    // Nos suscribimos ANTES de initialize para no perder solicitudes
    // que ya estén en el buzón del QR.
    _inviteSub = service.inviteRequests.listen(_onInviteRequest);
    await service.initialize();
    _statusSub = service.status.listen(_showStatus);
    _showStatus(service.currentStatus);
  }

  Future<void> _stopSync() async {
    await _statusSub?.cancel();
    _statusSub = null;
    await _inviteSub?.cancel();
    _inviteSub = null;
    final service = _sync;
    _sync = null;
    await service?.dispose();
  }

  /// Solicitud nueva en el buzón del QR (solo la recibe el host).
  /// Con la app cerrada, esta es la que dispara la notificación.
  Future<void> _onInviteRequest(InviteRequest request) async {
    try {
      final token = await KeyStore().getActiveInviteToken();
      if (token == null) return;
      final valid = InviteService(CryptoService()).verifyProof(
        inviteToken: token,
        guestDeviceId: request.guestDeviceId,
        proof: request.proof,
      );
      if (!valid) return;
      await _notifications?.show(
        title: 'Nueva solicitud',
        body: '${request.displayName} quiere unirse a tu relación.',
        id: NotificationService.stableId(
            'join_${request.guestDeviceId}_${request.createdAt}'),
      );
    } catch (e) {
      debugPrint('[BackgroundSync] Error en invite request: $e');
    }
  }

  void _showStatus(SyncStatus status) {
    final text = switch (status) {
      SyncStatus.online => 'Conectado',
      SyncStatus.syncing => 'Conectando…',
      SyncStatus.offline => 'Sin conexión',
      SyncStatus.unpaired => 'Sin pareja vinculada',
      SyncStatus.error => 'Error de conexión',
    };
    FlutterForegroundTask.updateService(
      notificationTitle: 'Ailoviu',
      notificationText: text,
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    final service = _sync;
    final needsRestart = service == null ||
        service.currentStatus == SyncStatus.error ||
        service.currentStatus == SyncStatus.unpaired;
    if (!needsRestart || _restarting) return;

    _restarting = true;
    _startSync().whenComplete(() => _restarting = false);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _stopSync();
  }

  @override
  void onReceiveData(Object data) {
    // La app avisa que cambió el token del QR o los miembros.
    if (data == 'reloadPeers') {
      final service = _sync;
      if (service != null) unawaited(service.reloadPeers());
    }
  }

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}
}

class BackgroundSyncService {
  BackgroundSyncService._();

  static const String _prefKey = 'settings.backgroundSync';
  static const int _serviceId = 4101;
  static bool _initialized = false;

  static void _init() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'ailoviu_sync_service',
        channelName: 'Conexión en segundo plano',
        channelDescription:
            'Mantiene Ailoviu conectado para recibir mensajes con la app cerrada.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    if (value) {
      await start();
    } else {
      await stop();
    }
  }

  /// Al abrir la app: si hay pareja, transporte configurado y el
  /// usuario no lo desactivó, se asegura de que el servicio corra.
  /// También arranca si soy host y tengo un inviteToken activo.
  static Future<void> bootstrap() async {
    try {
      if (!await isEnabled()) return;
      final keyStore = KeyStore();
      
      final isLinked = await keyStore.isLinked();
      final hasActiveInvite = await keyStore.isHostWithActiveInvite();
      
      // Si no hay pareja Y no estoy esperando a nadie, no arrancamos.
      if (!isLinked && !hasActiveInvite) return;
      
      final config = await TransportConfig.load(keyStore);
      if (!config.isConfigured) return;
      
      await start();
    } catch (e) {
      debugPrint('[BackgroundSyncService] Error en bootstrap: $e');
    }
  }

  /// Avisa al servicio (otro aislado) que recargue peers y el token
  /// del QR activo. No hace nada si el servicio no está corriendo.
  static Future<void> notifyReload() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        FlutterForegroundTask.sendDataToTask('reloadPeers');
      }
    } catch (e) {
      debugPrint('[BackgroundSyncService] Error en notifyReload: $e');
    }
  }

  static Future<bool> start() async {
    _init();
    await _requestPermissions();
    if (await FlutterForegroundTask.isRunningService) return true;

    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [ForegroundServiceTypes.remoteMessaging],
      notificationTitle: 'Ailoviu',
      notificationText: 'Conectando…',
      callback: startBackgroundSync,
    );
    return FlutterForegroundTask.isRunningService;
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }

  static Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  static Future<void> _requestPermissions() async {
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }
}