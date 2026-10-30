import 'package:flutter/material.dart';

/// Paleta y configuración del mapa de Hogar.
class MapStyle {
  MapStyle._();

  // ── URLs de los tiles ──────────────────────────────────────────────
  
  /// CARTO Voyager (claro).
  static String getTileUrl(String key) {
    if (key.isEmpty) return osmTileUrl;
    return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png?key=$key';
  }

  /// CARTO Dark Matter (oscuro).
  static String getTileUrlDark(String key) {
    if (key.isEmpty) return osmTileUrl;
    return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png?key=$key';
  }

  /// OSM estándar (fallback si no hay API key).
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String attributionCarto = 'OpenStreetMap · CARTO';
  static const String attributionOsm = '© OpenStreetMap contributors';

  // ── Fondos mientras cargan los tiles ───────────────────────────────
  static const Color bgLight = Color(0xFFF2EFE9);
  static const Color bgDark = Color(0xFF1A1A1A);
  static const Color bgAmoled = Color(0xFF0A0A0A);

  // ── Filtro AMOLED ──────────────────────────────────────────────────
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