# ARQUITECTURA

## Stack técnico
- **Framework:** Flutter 3.47.7 (Dart)
- **Diseño:** Material 3 (M3 Expressive a futuro, package pendiente)
- **Package ID:** com.iruletas.ailoviu
- **Estado global:** `flutter_riverpod` 2.x
- **Persistencia local:** `shared_preferences` 2.x
- **CI/CD:** GitHub Actions (ubuntu-22.04, Java 17)
- **Firma:** Keystore `.jks` inyectado por Base64 en Secrets.
- **Estrategia de Gradle:** Inyección quirúrgica por Python en
  `build.gradle.kts` para evitar conflictos con AGP 9.0.

## Estructura de `lib/`

Organización **por capa, plana, sin subcarpetas**. Un archivo se ubica
según **qué es**, no según a qué pantalla pertenece.

```

lib/
├── main.dart                    ← punto de entrada
├── app.dart                     ← MaterialApp + tema
├── core/                        ← configuración transversal
│   ├── app_theme.dart
│   └── seed_palette.dart
├── providers/                   ← estado global (Riverpod)
│   ├── settings_providers.dart
│   └── relationship_providers.dart
├── screens/                     ← pantallas
│   ├── main_shell.dart
│   ├── home_screen.dart
│   ├── calendar_screen.dart
│   ├── connection_screen.dart
│   ├── play_screen.dart
│   ├── settings_screen.dart
│   ├── appearance_screen.dart
│   ├── relationship_screen.dart
│   └── about_screen.dart
└── widgets/                     ← widgets reutilizables
└── relationship_preview.dart

```

### Regla de `core/`
`core/` contiene **solo** configuración, constantes, formateadores y
helpers puros que no encajan en `providers/`, `screens/` ni `widgets/`.
**Nunca** se mete en `core/` un modelo, un provider, una pantalla ni un
widget. No es un basurero: es "lo transversal que no es ninguna de las
otras categorías".

### Regla de carpetas
Las carpetas de `lib/` son **planas** (sin subcarpetas dentro de
`screens/`, `providers/`, etc.) hasta que una supere ~15 archivos. Si
algún día se subdivide, se hace dentro de esa capa (ej.
`screens/settings/`), y se agrupa en un solo commit para no invalidar el
caché de Gradle varias veces.

### Regla de nomenclatura
- Archivos: `snake_case` con sufijo por capa: `*_screen.dart`,
  `*_providers.dart`, `*_preview.dart`.
- Clases: `PascalCase`.
- Claves de `shared_preferences`: con prefijo por dominio
  (`settings.*`, `relationship.*`, `diary.*`, `period.*`, etc.).

## Regla: pantallas principales delgadas

Ninguna `*_screen.dart` de nivel superior debe contener lógica ni UI
compleja. Su responsabilidad es:
1. Leer estado (`ref.watch`).
2. Componer `ListTile`s / botones de navegación.
3. Delegar el cuerpo real a widgets o screens secundarias.

Si una screen supera ~150 líneas, es señal de que su contenido debe
extraerse a `widgets/` (trozos reutilizables) o a otra screen.

**Ejemplo aplicado:** `settings_screen.dart` es un hub de `ListTile`s
que navegan a `appearance_screen.dart`, `relationship_screen.dart` y
`about_screen.dart`. Nunca crece; crece el número de destinos.

## Regla: scroll en pantallas principales

Las pantallas principales **intentan** caber sin scroll vertical en un
celular estándar (~360×800 dp). Si el contenido no cabe por razones
justificadas (3+ miembros, accesibilidad con fuente grande, listas
largas), se permite `SingleChildScrollView`. **No es un fracaso**: es
una decisión consciente.

Orden de preferencia cuando no cabe:
1. **Reducir**: menos texto, iconos más compactos, menos padding.
2. **Agrupar**: consolidar controles (ej. `SegmentedButton` en vez de 3
   `RadioListTile`).
3. **Scroll**: `SingleChildScrollView` con justificación.

## Regla: hub de ajustes

`settings_screen.dart` es un hub de navegación, no un formulario.
Contiene `ListTile`s que abren screens secundarias o diálogos pequeños
(≤3 inputs). Los toggles simples (`SwitchListTile`) pueden quedarse en
el hub; todo lo demás va a su propia screen. Cada `ListTile` muestra en
`subtitle` el valor actual del setting.

## Regla de idioma (UI)

- **Sentence case** en toda la UI: "Datos de la relación", no "Datos De
  La Relación".
- **Español mexicano o neutro**. Evitar castellanismos:
  - "agrega" (no "añade"), "elimina" (no "borra"), "celular" (no "móvil"),
    "computadora" (no "ordenador"), "archivo" (no "fichero"),
    "presionar/tocar" (no "pulsar"), "ustedes" (no "vosotros"),
    "elegir/seleccionar" (no "coger").
- **"Relación"** en UI, nunca "pareja" (la app soporta 2+ miembros).
  En código, los archivos usan `relationship_*`.

## Nota sobre el NDK y CMake
Flutter 3.47.7 pide NDK r28c y CMake por defecto al generar `android/`,
aunque la app no tenga código nativo. La descarga puede fallar
esporádicamente (`Archive is not a ZIP archive`), sobre todo cuando el
caché de Gradle se invalida (ej. tras mover archivos en `lib/`).
**Solución**: re-lanzar el workflow. Si se vuelve recurrente, añadir
paso de limpieza de NDK o cambiar a `ubuntu-24.04`.

## Backend — pendiente de diseño
Ver `tools/PENDIENTES.md` ítems 1 y 2. Se abordan cuando se decida
backend, identidad y modelo de borrado criptográfico. No se improvisa.