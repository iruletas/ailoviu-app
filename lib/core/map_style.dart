import 'package:flutter/material.dart';

/// Paleta del mapa de Hogar. Estilo "caricatura" limpia.
class MapStyle {
  MapStyle._();

  /// Matriz de color para `ColorFiltered`.
  /// Esta matriz desatura un poco los colores y les da un toque de brillo
  /// (offset 20) para un look limpio, pero sin quemar los detalles a blanco puro.
  static const List<double> colorMatrix = [
    1.0, 0.2, 0.2, 0, 20, // R
    0.2, 1.0, 0.2, 0, 20, // G
    0.2, 0.2, 1.0, 0, 20, // B
    0.0, 0.0, 0.0, 1.0, 0,  // A
  ];

  /// Color de la línea de distancia entre los dos avatares.
  static const Color lineColor = Color(0xFFE91E63);

  /// Grosor de la línea de distancia.
  static const double lineWidth = 3.0;

  /// Zoom inicial del mapa.
  static const double initialZoom = 14.0;

  /// Zoom máximo.
  static const double maxZoom = 18.0;

  /// Zoom mínimo.
  static const double minZoom = 1.0;

  /// Posición por defecto si no hay ubicaciones (centro de México).
  static const double defaultLat = 23.6345;
  static const double defaultLon = -102.5528;

  /// URL de los tiles de OSM.
  static const String tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Atribución requerida por OSM.
  static const String attribution = '© OpenStreetMap contributors';
}