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
  stale,
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
/// - [getCurrentLocation]: obtiene la ubicación ahora (puede aceptar caché).
/// - [getFreshLocation]: obtiene una ubicación fresca, rechazando caché vieja.
/// - [distanceKmBetween]: distancia en km entre dos coordenadas.
///
/// El envío por sync de las ubicaciones NO se hace aquí: eso lo hace
/// `LocationsNotifier` cuando recibe cada nueva ubicación.
class LocationService {
  LocationService();

  /// Edad máxima aceptable para considerar una posición "fresca".
  /// Si el OS devuelve una posición más vieja que esto, se descarta.
  static const Duration maxStaleAge = Duration(minutes: 2);

  /// Timeout para [getFreshLocation]. Alto porque con `high` y GPS
  /// frío el primer fix puede tardar.
  static const Duration freshTimeout = Duration(seconds: 30);

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
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      return LocationResult.permissionDeniedForever;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.permissionDeniedForever;
      }
      if (permission == LocationPermission.denied) {
        return LocationResult.permissionDenied;
      }
    }

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
  /// antes. Puede devolver una posición cacheada del OS (no valida
  /// [PartnerLocation.capturedAt]). Para uso "fresco", usar
  /// [getFreshLocation].
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
          capturedAt: position.timestamp,
        ),
      );
    } on TimeoutException {
      return const LocationAttempt(result: LocationResult.timeout);
    } catch (_) {
      return const LocationAttempt(result: LocationResult.error);
    }
  }

  /// Obtiene una ubicación "fresca" para publicar en el mapa.
  ///
  /// A diferencia de [getCurrentLocation], esta variante:
  /// - Usa `LocationAccuracy.high`.
  /// - Da más tiempo (30s) para que el GPS tenga chance de un fix real.
  /// - **Rechaza** posiciones cuyo `timestamp` sea más viejo que
  ///   [maxStaleAge], devolviendo [LocationResult.stale]. Así nunca
  ///   publicamos caché del OS como si fuera nueva.
  ///
  /// No pide permisos: el caller debe haber llamado [ensurePermission]
  /// antes.
  Future<LocationAttempt> getFreshLocation({
    required String deviceId,
    Duration timeout = freshTimeout,
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      final age = DateTime.now().difference(position.timestamp);
      if (age > maxStaleAge) {
        return const LocationAttempt(result: LocationResult.stale);
      }

      return LocationAttempt(
        result: LocationResult.success,
        location: PartnerLocation(
          deviceId: deviceId,
          latitude: position.latitude,
          longitude: position.longitude,
          capturedAt: position.timestamp,
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
        capturedAt: position.timestamp,
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