import 'package:flutter/material.dart';

/// Paleta y configuración del mapa de Hogar.
class MapStyle {
  MapStyle._();

  // ── URLs de los tiles ──────────────────────────────────────────────
  /// CARTO Voyager (claro). Limpio, estilo Google Maps.
  static const String tileUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

  /// CARTO Dark Matter (oscuro). Ideal para el modo oscuro.
  static const String tileUrlDark =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

  /// Atribución requerida por OSM y CARTO.
  static const String attribution = '© OpenStreetMap · © CARTO';

  // ── Fondos mientras cargan los tiles ───────────────────────────────
  static const Color bgLight = Color(0xFFF2EFE9);
  static const Color bgDark = Color(0xFF1A1A1A);
  static const Color bgAmoled = Color(0xFF0A0A0A);

  // ── Filtro AMOLED ──────────────────────────────────────────────────
  /// Solo oscurece (multiplica por 0.75), nunca amplifica.
  /// Evita el bug de sobresaturación a blanco.
  static const List<double> amoledMatrix = [
    0.75, 0, 0, 0, 0,
    0, 0.75, 0, 0, 0,
    0, 0, 0.75, 0, 0,
    0, 0, 0, 1, 0,
  ];

  // ── Línea de distancia ─────────────────────────────────────────────
  static const Color lineColor = Color(0xFFE91E63);
  static const double lineWidth = 3.0;

  // ── Cámara ─────────────────────────────────────────────────────────
  static const double initialZoom = 14.0;
  static const double maxZoom = 18.0;
  static const double minZoom = 1.0;
  static const double defaultLat = 23.6345;
  static const double defaultLon = -102.5528;
}