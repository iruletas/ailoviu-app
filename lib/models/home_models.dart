import 'package:flutter/foundation.dart';

/// Estado de "cómo me siento ahora" de uno de los miembros.
///
/// Vive 24 horas. Al cargar, si expiró, se descarta y se muestra vacío.
/// El texto es libre (la pareja escribe lo que quiera), máximo 60
/// caracteres, con un emoji opcional al final.
@immutable
class PartnerStatus {
  /// deviceId del miembro que escribió el estado.
  final String authorDeviceId;

  /// Texto libre, máximo 60 caracteres.
  final String text;

  /// Emoji opcional al final del texto. `null` si no puso.
  final String? emoji;

  /// Momento en que se escribió. Se usa para expirar a las 24h.
  final DateTime writtenAt;

  const PartnerStatus({
    required this.authorDeviceId,
    required this.text,
    required this.writtenAt,
    this.emoji,
  });

  /// `true` si ya pasaron 24h desde [writtenAt].
  bool isExpired({DateTime? now}) {
    final current = now ?? DateTime.now();
    return current.difference(writtenAt) >= const Duration(hours: 24);
  }

  Map<String, dynamic> toJson() => {
        'authorDeviceId': authorDeviceId,
        'text': text,
        if (emoji != null) 'emoji': emoji,
        'writtenAt': writtenAt.toIso8601String(),
      };

  static PartnerStatus fromJson(Map<String, dynamic> json) => PartnerStatus(
        authorDeviceId: json['authorDeviceId'] as String,
        text: json['text'] as String,
        emoji: json['emoji'] as String?,
        writtenAt: DateTime.parse(json['writtenAt'] as String),
      );

  /// Texto con emoji al final, listo para mostrar en la UI.
  String get displayText => emoji == null ? text : '$text $emoji';
}

/// Última ubicación conocida de un miembro.
///
/// Se comparte por sync cifrado (Firebase solo ve el blob). Se actualiza
/// cuando el servicio en segundo plano corre y el permiso está concedido.
@immutable
class PartnerLocation {
  /// deviceId del miembro.
  final String deviceId;

  /// Latitud en grados.
  final double latitude;

  /// Longitud en grados.
  final double longitude;

  /// Momento en que se capturó (no cuando llegó).
  final DateTime capturedAt;

  const PartnerLocation({
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'latitude': latitude,
        'longitude': longitude,
        'capturedAt': capturedAt.toIso8601String(),
      };

  static PartnerLocation fromJson(Map<String, dynamic> json) => PartnerLocation(
        deviceId: json['deviceId'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        capturedAt: DateTime.parse(json['capturedAt'] as String),
      );
}

/// Estado del buzz (zumbido) en el dispositivo local.
///
/// Cooldown de 30s entre buzzes, máximo 50 por día. Se resetea a
/// medianoche local.
@immutable
class BuzzState {
  /// Momento del último buzz enviado. `null` si nunca.
  final DateTime? lastBuzzAt;

  /// Cuántos buzzes se han enviado hoy.
  final int todayCount;

  /// Fecha del día actual (para resetear el contador).
  final DateTime todayDate;

  const BuzzState({
    this.lastBuzzAt,
    this.todayCount = 0,
    required this.todayDate,
  });

  /// Cooldown entre buzzes.
  static const Duration cooldown = Duration(seconds: 30);

  /// Máximo de buzzes por día.
  static const int dailyLimit = 50;

  /// `true` si se puede mandar buzz ahora.
  bool canBuzz({DateTime? now}) {
    final current = now ?? DateTime.now();
    final isSameDay = _isSameDay(current, todayDate);
    final count = isSameDay ? todayCount : 0;

    if (count >= dailyLimit) return false;
    if (lastBuzzAt == null) return true;
    return current.difference(lastBuzzAt!) >= cooldown;
  }

  /// Tiempo restante de cooldown, o `null` si no hay cooldown activo.
  Duration? remainingCooldown({DateTime? now}) {
    if (lastBuzzAt == null) return null;
    final current = now ?? DateTime.now();
    final elapsed = current.difference(lastBuzzAt!);
    if (elapsed >= cooldown) return null;
    return cooldown - elapsed;
  }

  /// Cuántos buzzes quedan hoy.
  int remainingToday({DateTime? now}) {
    final current = now ?? DateTime.now();
    final isSameDay = _isSameDay(current, todayDate);
    return dailyLimit - (isSameDay ? todayCount : 0);
  }

  BuzzState markSent(DateTime now) {
    final isSameDay = _isSameDay(now, todayDate);
    return BuzzState(
      lastBuzzAt: now,
      todayCount: (isSameDay ? todayCount : 0) + 1,
      todayDate: now,
    );
  }

  BuzzState resetIfNewDay(DateTime now) {
    if (_isSameDay(now, todayDate)) return this;
    return BuzzState(
      lastBuzzAt: lastBuzzAt,
      todayCount: 0,
      todayDate: now,
    );
  }

  Map<String, dynamic> toJson() => {
        if (lastBuzzAt != null)
          'lastBuzzAt': lastBuzzAt!.toIso8601String(),
        'todayCount': todayCount,
        'todayDate': todayDate.toIso8601String(),
      };

  static BuzzState fromJson(Map<String, dynamic> json) => BuzzState(
        lastBuzzAt: json['lastBuzzAt'] != null
            ? DateTime.parse(json['lastBuzzAt'] as String)
            : null,
        todayCount: json['todayCount'] as int? ?? 0,
        todayDate: DateTime.parse(json['todayDate'] as String),
      );

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Configuración del contador de distancia.
///
/// Dos modos independientes: km fijos entre ciudades, o días desde la
/// última vez que se vieron. Ambos opcionales.
@immutable
class DistanceConfig {
  /// Km entre las dos ciudades. `null` si no configurado.
  final int? fixedKm;

  /// Fecha de la última vez que se vieron. `null` si no configurado.
  final DateTime? lastSeenAt;

  const DistanceConfig({
    this.fixedKm,
    this.lastSeenAt,
  });

  bool get hasAny => fixedKm != null || lastSeenAt != null;

  DistanceConfig copyWith({
    int? fixedKm,
    DateTime? lastSeenAt,
    bool clearFixedKm = false,
    bool clearLastSeenAt = false,
  }) {
    return DistanceConfig(
      fixedKm: clearFixedKm ? null : (fixedKm ?? this.fixedKm),
      lastSeenAt:
          clearLastSeenAt ? null : (lastSeenAt ?? this.lastSeenAt),
    );
  }

  Map<String, dynamic> toJson() => {
        if (fixedKm != null) 'fixedKm': fixedKm,
        if (lastSeenAt != null)
          'lastSeenAt': lastSeenAt!.toIso8601String(),
      };

  static DistanceConfig fromJson(Map<String, dynamic> json) => DistanceConfig(
        fixedKm: json['fixedKm'] as int?,
        lastSeenAt: json['lastSeenAt'] != null
            ? DateTime.parse(json['lastSeenAt'] as String)
            : null,
      );
}