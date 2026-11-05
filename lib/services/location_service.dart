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
/// - [getCurrentLocation]: obtiene la ubicación ahora (acepta caché).
/// - [getFreshLocation]: cascada medium → high → last-known. Diseñada
///   para funcionar en dispositivos sin GPS (tablets, emuladores) que
///   sólo tienen WiFi/cell.
/// - [distanceKmBetween]: distancia en km entre dos coordenadas.
class LocationService {
  LocationService();

  /// Antigüedad máxima aceptable para considerar una posición "fresca".
  ///
  /// 10 minutos porque en tablets el SO cachea la posición WiFi y no la
  /// actualiza hasta que alguien la pide. Rechazar todo lo que pase de
  /// 2 min deja a la tablet sin ubicación para siempre.
  static const Duration maxStaleAge = Duration(minutes: 10);

  /// Timeout por intento de la cascada. 15s es suficiente para un fix
  /// WiFi; si no, pasamos al siguiente método.
  static const Duration freshTimeout = Duration(seconds: 15);

  // ── Permisos ────────────────────────────────────────────────────────

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

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> hasBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  // ── Obtención de posición ───────────────────────────────────────────

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

  /// Obtiene una ubicación utilizable, con cascada de tres pasos:
  ///
  /// 1. **medium** (WiFi/cell). Rápido, confiable en cualquier
  ///    dispositivo, incluidos tablets sin GPS. Es el caballo de
  ///    batalla.
  /// 2. **high** (GPS). Más preciso, sólo si el paso 1 falló. En
  ///    tablets sin GPS va a fallar de nuevo, pero no cuesta nada
  ///    intentarlo antes de rendirse.
  /// 3. **getLastKnownPosition**. Lo último que el SO tenga cacheado.
  ///    Puede estar viejo, pero es mejor que nada. Se marca como
  ///    exitoso porque el mapa puede mostrarlo sin problemas.
  ///
  /// No pide permisos: el caller debe haber llamado [ensurePermission]
  /// antes.
  Future<LocationAttempt> getFreshLocation({
    required String deviceId,
    Duration timeout = freshTimeout,
  }) async {
    // 1. Medium: rápido, confiable.
    final medium = await _tryPosition(
      deviceId: deviceId,
      accuracy: LocationAccuracy.medium,
      timeout: timeout,
      requireFresh: true,
    );
    if (medium != null) return medium;

    // 2. High: GPS, por si el usuario está al aire libre.
    final high = await _tryPosition(
      deviceId: deviceId,
      accuracy: LocationAccuracy.high,
      timeout: const Duration(seconds: 10),
      requireFresh: true,
    );
    if (high != null) return high;

    // 3. Last known: lo último que el SO recuerde.
    final last = await _lastKnown(deviceId: deviceId);
    if (last != null) return last;

    return const LocationAttempt(result: LocationResult.timeout);
  }

  Future<LocationAttempt?> _tryPosition({
    required String deviceId,
    required LocationAccuracy accuracy,
    required Duration timeout,
    required bool requireFresh,
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );

      if (requireFresh) {
        final age = DateTime.now().difference(position.timestamp);
        if (age > maxStaleAge) return null;
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
    } catch (_) {
      return null;
    }
  }

  Future<LocationAttempt?> _lastKnown({required String deviceId}) async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) return null;
      return LocationAttempt(
        result: LocationResult.success,
        location: PartnerLocation(
          deviceId: deviceId,
          latitude: last.latitude,
          longitude: last.longitude,
          capturedAt: last.timestamp,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Background ──────────────────────────────────────────────────────

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

  // ── Util ────────────────────────────────────────────────────────────

  double distanceKmBetween({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final meters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return meters / 1000.0;
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}