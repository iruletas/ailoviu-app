import 'package:flutter/material.dart';

/// Paleta del mapa de Hogar. Estilo "caricatura": colores suaves,
/// sin satélite, calles redondeadas y parques en tonos pastel.
///
/// Se usa como referencia para el `TileLayer` de `flutter_map`
/// (que no permite recolorear tiles directamente, pero sí aplicar
/// un filtro de color global con `ColorFiltered`).
///
/// NOTA: `flutter_map` no soporta estilos JSON como Google Maps.
/// Para cambiar la paleta, envolvemos el mapa en un `ColorFiltered`.
/// Es limitado pero suficiente para el look "caricatura".
class MapStyle {
  MapStyle._();

  /// Color de fondo del mapa (tierra).
  static const Color background = Color(0xFFF5EDE0);

  /// Tinte aplicado sobre los tiles de OSM para suavizarlos.
  static const Color tint = Color(0x33F5EDE0);

  /// Color de la línea de distancia entre los dos avatares.
  static const Color lineColor = Color(0xFFE91E63);

  /// Grosor de la línea de distancia.
  static const double lineWidth = 3.0;

  /// Zoom inicial del mapa.
  static const double initialZoom = 4.0;

  /// Zoom máximo.
  static const double maxZoom = 18.0;

  /// Zoom mínimo (no dejar salir del planeta).
  static const double minZoom = 1.0;

  /// Posición por defecto si no hay ubicaciones (centro de México).
  static const double defaultLat = 23.6345;
  static const double defaultLon = -102.5528;

  /// URL de los tiles de OSM.
  static const String tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Atribución requerida por OSM.
  static const String attribution =
      '© OpenStreetMap contributors';
}