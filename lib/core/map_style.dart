import 'package:flutter/material.dart';

/// Paleta del mapa de Hogar. Estilo "caricatura" limpia.
class MapStyle {
  MapStyle._();

  /// Tinte aplicado sobre los tiles de OSM.
  /// Multiplicamos los colores por gris claro para bajar saturación.
  static const Color tint = Color(0xFFFFFFFF);

  /// Matriz de color para `ColorFiltered`.
  /// Esta matriz convierte el mapa a un estilo blanco/gris suave.
  /// (Aumenta el brillo, reduce el contraste de los colores).
  static const List<double> colorMatrix = [
    1.3, 0, 0, 0, 50, // R
    0, 1.3, 0, 0, 50, // G
    0, 0, 1.3, 0, 50, // B
    0, 0, 0, 0.85, 0, // A (un poco transparente para que se integre)
  ];

  /// Color de la línea de distancia entre los dos avatares.
  static const Color lineColor = Color(0xFFE91E63);

  /// Grosor de la línea de distancia.
  static const double lineWidth = 3.0;

  /// Zoom inicial del mapa.
  static const double initialZoom = 14.0; // un poco más cerca

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