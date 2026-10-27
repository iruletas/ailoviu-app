/// Las 35 formas de Material 3 Expressive, tal como las define Google en
/// `androidx.compose.material3.MaterialShapes`.
///
/// Los nombres son idénticos a los del upstream para que el mapeo sea
/// 1:1 en [m3ePolygon] y no haya ambigüedad.
enum M3EShape {
  // Basic (7)
  circle,
  square,
  slanted,
  arch,
  semiCircle,
  oval,
  pill,

  // Playful — el orden sigue el upstream, no la categoría.
  triangle,
  arrow,
  fan,
  diamond,
  clamShell,
  pentagon,
  gem,

  // Organic / Playful
  sunny,
  verySunny,

  // Cookie
  cookie4Sided,
  cookie6Sided,
  cookie7Sided,
  cookie9Sided,
  cookie12Sided,

  // Organic
  clover4Leaf,
  clover8Leaf,

  // Playful
  burst,
  softBurst,
  boom,
  softBoom,

  // Organic
  flower,

  // Whimsical
  puffy,
  puffyDiamond,

  // Special / Whimsical
  ghostish,

  // Pixel
  pixelCircle,
  pixelTriangle,

  // Special / Whimsical
  bun,

  // Special
  heart,
}

/// Las 7 categorías oficiales de Material 3 Expressive.
enum M3EShapeCategory {
  basic,
  organic,
  playful,
  cookie,
  whimsical,
  special,
  pixel,
}

extension M3EShapeCategoryLabel on M3EShapeCategory {
  String get label {
    switch (this) {
      case M3EShapeCategory.basic:
        return 'Básicas';
      case M3EShapeCategory.organic:
        return 'Orgánicas';
      case M3EShapeCategory.playful:
        return 'Juguetosas';
      case M3EShapeCategory.cookie:
        return 'Galletas';
      case M3EShapeCategory.whimsical:
        return 'Caprichosas';
      case M3EShapeCategory.special:
        return 'Especiales';
      case M3EShapeCategory.pixel:
        return 'Pixel';
    }
  }
}

extension M3EShapeCategoryLookup on M3EShape {
  M3EShapeCategory get category {
    switch (this) {
      case M3EShape.circle:
      case M3EShape.square:
      case M3EShape.slanted:
      case M3EShape.arch:
      case M3EShape.semiCircle:
      case M3EShape.oval:
      case M3EShape.pill:
        return M3EShapeCategory.basic;
      case M3EShape.flower:
      case M3EShape.clover4Leaf:
      case M3EShape.clover8Leaf:
        return M3EShapeCategory.organic;
      case M3EShape.triangle:
      case M3EShape.arrow:
      case M3EShape.fan:
      case M3EShape.diamond:
      case M3EShape.clamShell:
      case M3EShape.pentagon:
      case M3EShape.gem:
      case M3EShape.sunny:
      case M3EShape.verySunny:
      case M3EShape.burst:
      case M3EShape.softBurst:
      case M3EShape.boom:
      case M3EShape.softBoom:
        return M3EShapeCategory.playful;
      case M3EShape.cookie4Sided:
      case M3EShape.cookie6Sided:
      case M3EShape.cookie7Sided:
      case M3EShape.cookie9Sided:
      case M3EShape.cookie12Sided:
        return M3EShapeCategory.cookie;
      case M3EShape.puffy:
      case M3EShape.puffyDiamond:
      case M3EShape.ghostish:
      case M3EShape.bun:
        return M3EShapeCategory.whimsical;
      case M3EShape.heart:
        return M3EShapeCategory.special;
      case M3EShape.pixelCircle:
      case M3EShape.pixelTriangle:
        return M3EShapeCategory.pixel;
    }
  }

  /// Clave estable para persistencia en `SecureStorage`.
  ///
  /// Coincide con el nombre del enum. Los valores legacy `'clover'` y
  /// `'softBurst'` se mantienen por compatibilidad con la app anterior.
  String get key {
    switch (this) {
      case M3EShape.clover4Leaf:
        // Legacy: en la app anterior se guardaba como 'clover'.
        // Al serializar, usamos el nombre nuevo. El fromKey tolera
        // ambos. Así el storage se migra solo la próxima vez que el
        // usuario guarde una forma.
        return 'clover4Leaf';
      default:
        return name;
    }
  }

  /// Label humano en español para el picker.
  String get label {
    switch (this) {
      case M3EShape.circle:
        return 'Círculo';
      case M3EShape.square:
        return 'Cuadrado';
      case M3EShape.slanted:
        return 'Inclinado';
      case M3EShape.arch:
        return 'Arco';
      case M3EShape.semiCircle:
        return 'Semicírculo';
      case M3EShape.oval:
        return 'Óvalo';
      case M3EShape.pill:
        return 'Píldora';
      case M3EShape.triangle:
        return 'Triángulo';
      case M3EShape.arrow:
        return 'Flecha';
      case M3EShape.fan:
        return 'Abanico';
      case M3EShape.diamond:
        return 'Diamante';
      case M3EShape.clamShell:
        return 'Concha';
      case M3EShape.pentagon:
        return 'Pentágono';
      case M3EShape.gem:
        return 'Gema';
      case M3EShape.sunny:
        return 'Soleado';
      case M3EShape.verySunny:
        return 'Muy soleado';
      case M3EShape.cookie4Sided:
        return 'Galleta 4';
      case M3EShape.cookie6Sided:
        return 'Galleta 6';
      case M3EShape.cookie7Sided:
        return 'Galleta 7';
      case M3EShape.cookie9Sided:
        return 'Galleta 9';
      case M3EShape.cookie12Sided:
        return 'Galleta 12';
      case M3EShape.clover4Leaf:
        return 'Trébol 4';
      case M3EShape.clover8Leaf:
        return 'Trébol 8';
      case M3EShape.burst:
        return 'Estallido';
      case M3EShape.softBurst:
        return 'Estallido suave';
      case M3EShape.boom:
        return 'Boom';
      case M3EShape.softBoom:
        return 'Boom suave';
      case M3EShape.flower:
        return 'Flor';
      case M3EShape.puffy:
        return 'Esponjado';
      case M3EShape.puffyDiamond:
        return 'Diamante esponjado';
      case M3EShape.ghostish:
        return 'Fantasma';
      case M3EShape.pixelCircle:
        return 'Pixel círculo';
      case M3EShape.pixelTriangle:
        return 'Pixel triángulo';
      case M3EShape.bun:
        return 'Bollo';
      case M3EShape.heart:
        return 'Corazón';
    }
  }
}

extension M3EShapeLookup on M3EShape {
  /// Lista completa de las 35 formas.
  static const List<M3EShape> all = [
    M3EShape.circle,
    M3EShape.square,
    M3EShape.slanted,
    M3EShape.arch,
    M3EShape.semiCircle,
    M3EShape.oval,
    M3EShape.pill,
    M3EShape.triangle,
    M3EShape.arrow,
    M3EShape.fan,
    M3EShape.diamond,
    M3EShape.clamShell,
    M3EShape.pentagon,
    M3EShape.gem,
    M3EShape.sunny,
    M3EShape.verySunny,
    M3EShape.cookie4Sided,
    M3EShape.cookie6Sided,
    M3EShape.cookie7Sided,
    M3EShape.cookie9Sided,
    M3EShape.cookie12Sided,
    M3EShape.clover4Leaf,
    M3EShape.clover8Leaf,
    M3EShape.burst,
    M3EShape.softBurst,
    M3EShape.boom,
    M3EShape.softBoom,
    M3EShape.flower,
    M3EShape.puffy,
    M3EShape.puffyDiamond,
    M3EShape.ghostish,
    M3EShape.pixelCircle,
    M3EShape.pixelTriangle,
    M3EShape.bun,
    M3EShape.heart,
  ];

  /// Formas agrupadas por categoría, en el orden de [all].
  static Map<M3EShapeCategory, List<M3EShape>> get byCategory {
    final result = <M3EShapeCategory, List<M3EShape>>{};
    for (final s in all) {
      result.putIfAbsent(s.category, () => []).add(s);
    }
    return result;
  }

  /// Resuelve un [M3EShape] desde su clave persistida.
  ///
  /// Tolerante a valores legacy: `'clover'` → [clover4Leaf]. `'clover8'`
  /// no existía, cae al default.
  static M3EShape fromKey(String? key) {
    if (key == null || key.isEmpty) return M3EShape.pill;
    switch (key) {
      case 'square':
        return M3EShape.square;
      case 'pill':
        return M3EShape.pill;
      case 'oval':
        return M3EShape.oval;
      case 'circle':
        return M3EShape.circle;
      case 'pentagon':
        return M3EShape.pentagon;
      case 'sunny':
        return M3EShape.sunny;
      case 'clover':
        return M3EShape.clover4Leaf;
      case 'softBurst':
        return M3EShape.softBurst;
      default:
        for (final s in M3EShapeLookup.all) {
          if (s.name == key) return s;
        }
        return M3EShape.pill;
    }
  }
}