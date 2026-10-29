import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/home_models.dart';

/// Servicio de ubicación.
///
/// - [requestPermission]: pide permiso foreground y background.
/// - [getCurrentLocation]: obtiene la ubicación ahora (foreground).
/// - [startBackgroundUpdates]: stream de ubicaciones mientras la app
///   corre en segundo plano. Usa `flutter_foreground_task` (ya activo).
/// - [distanceKmBetween]: distancia en km entre dos coordenadas.
///
/// El envío por sync de las ubicaciones NO se hace aquí: eso lo hace
/// `background_sync.dart` cuando recibe cada nueva ubicación.
class LocationService {
  LocationService();

  /// Pide permiso foreground + background.
  ///
  /// Devuelve `true` si ambos permisos quedaron concedidos.
  /// Background solo se pide si foreground fue concedido.
  Future<bool> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    // Background: solo aplica en Android. En iOS se maneja distinto.
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// `true` si hay permiso para leer ubicación ahora.
  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// `true` si hay permiso de background (always).
  Future<bool> hasBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  /// Obtiene la ubicación actual. `null` si no hay permiso o falla.
  Future<PartnerLocation?> getCurrentLocation({
    required String deviceId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!await hasPermission()) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );
      return PartnerLocation(
        deviceId: deviceId,
        latitude: position.latitude,
        longitude: position.longitude,
        capturedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Stream de ubicaciones en background.
  ///
  /// Frecuencia moderada (cada 5 min o 100 m de movimiento): el mapa
  /// no necesita más precisión y ahorramos batería.
  ///
  /// Requiere permiso de background concedido.
  Stream<PartnerLocation> backgroundUpdates({
    required String deviceId,
  }) async* {
    if (!await hasBackgroundPermission()) return;

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 100,
      intervalDuration: const Duration(minutes: 5),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Ailoviu',
        notificationText: 'Compartiendo ubicación con tu relación',
        notificationChannelName: 'Ubicación',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );

    await for (final position in Geolocator.getPositionStream(
      locationSettings: settings,
    )) {
      yield PartnerLocation(
        deviceId: deviceId,
        latitude: position.latitude,
        longitude: position.longitude,
        capturedAt: DateTime.now(),
      );
    }
  }

  /// Distancia en km entre dos coordenadas.
  double distanceKmBetween({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final meters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return meters / 1000.0;
  }

  /// Abre los ajustes del sistema para conceder permisos manualmente.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Abre los ajustes de ubicación del sistema.
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}