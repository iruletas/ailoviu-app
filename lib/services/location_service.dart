import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/home_models.dart';

/// Resultado de un intento de obtener ubicación.
///
/// Permite distinguir entre "no hay permiso", "el servicio de ubicación
/// está apagado", y "no se pudo obtener la posición".
enum LocationResult {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  error,
}

class LocationAttempt {
  final LocationResult result;
  final PartnerLocation? location;

  const LocationAttempt({required this.result, this.location});

  bool get isSuccess => result == LocationResult.success;
}

/// Servicio de ubicación.
///
/// - [ensurePermission]: chequea y pide permisos si es necesario.
/// - [getCurrentLocation]: obtiene la ubicación ahora.
/// - [distanceKmBetween]: distancia en km entre dos coordenadas.
///
/// El envío por sync de las ubicaciones NO se hace aquí: eso lo hace
/// `background_sync.dart` cuando recibe cada nueva ubicación.
class LocationService {
  LocationService();

  /// Asegura que haya permiso de ubicación concedido.
  ///
  /// Reglas:
  /// - Si el servicio de ubicación del sistema está apagado, retorna
  ///   [LocationResult.serviceDisabled].
  /// - Si ya hay permiso `whileInUse` o `always`, retorna
  ///   [LocationResult.success] **sin volver a pedir** (evita el bug
  ///   de Android que devuelve `denied` al re-pedir un permiso ya
  ///   concedido).
  /// - Si no hay permiso, lo pide una vez.
  Future<LocationResult> ensurePermission() async {
    // 1. Servicio del sistema encendido.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult.serviceDisabled;
    }

    // 2. Permiso actual.
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      return LocationResult.permissionDeniedForever;
    }

    if (permission == LocationPermission.denied) {
      // Pedir una vez.
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.permissionDeniedForever;
      }
      if (permission == LocationPermission.denied) {
        return LocationResult.permissionDenied;
      }
    }

    // 3. Con `whileInUse` o `always` ya sirve para el mapa.
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      return LocationResult.success;
    }

    return LocationResult.permissionDenied;
  }

  /// `true` si el servicio de ubicación del sistema está encendido.
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// `true` si hay permiso de foreground (o background).
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

  /// Obtiene la ubicación actual.
  ///
  /// No pide permisos: el caller debe haber llamado [ensurePermission]
  /// antes. Devuelve [LocationAttempt] con el resultado y la ubicación.
  Future<LocationAttempt> getCurrentLocation({
    required String deviceId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );
      return LocationAttempt(
        result: LocationResult.success,
        location: PartnerLocation(
          deviceId: deviceId,
          latitude: position.latitude,
          longitude: position.longitude,
          capturedAt: DateTime.now(),
        ),
      );
    } on TimeoutException {
      return const LocationAttempt(result: LocationResult.timeout);
    } catch (_) {
      return const LocationAttempt(result: LocationResult.error);
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