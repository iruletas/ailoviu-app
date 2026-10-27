# ARQUITECTURA

Este documento define **reglas duras** del proyecto. No es un inventario
de lo que existe (para eso está `ESTADO.md`) ni una guía de lo pendiente
(para eso está `PENDIENTES.md`). Es el conjunto de decisiones que un
agente debe respetar **sin preguntar** y que un humano debe seguir para
no romper la coherencia del código.

Cuando una regla entre en conflicto con una petición concreta, se
discute explícitamente antes de romperla.

---

## 1. Stack técnico

- Flutter 3.47.7 · Dart 3.13.x
- Material 3 Expressive
- Estado: `flutter_riverpod` 2.x (StateNotifier, sin codegen)
- Persistencia: `shared_preferences` 2.x
- Info del bundle: `package_info_plus` 8.x
- Formas M3E: `m3e_shapes` (paquete local en `packages/`)
- Progreso M3E: `m3e_progress` (paquete local, aún sin integrar)
- CI/CD: GitHub Actions · ubuntu-24.04 · Java 17
- Firma: keystore `.jks` inyectado por Base64 en Secrets
- Versionado: automático por `github.run_number`

---

## 2. Estructura de carpetas

### `lib/` — organización por capa, plana

```

lib/
├── main.dart              ← runApp, nada más
├── app.dart               ← MaterialApp + tema
├── core/                  ← config transversal (ver regla 3)
├── providers/             ← estado global (Riverpod)
├── screens/               ← pantallas
└── widgets/               ← widgets reutilizables (ver regla 4)

```

**Reglas de carpetas:**
- Planas. Sin subcarpetas dentro de `screens/`, `providers/`, etc.
  hasta que una capa supere ~15 archivos.
- Si una capa se subdivide, se hace **dentro** de la capa
  (`screens/settings/...`) y en **un solo commit** para no invalidar
  el caché de Gradle varias veces.
- Un archivo se ubica según **qué es** (provider, screen, widget,
  config), nunca según a qué pantalla pertenece.

### `packages/` — paquetes locales de código propio

```

packages/
├── m3e_shapes/      ← formas M3E (35 formas, morph, clip)
└── m3e_progress/    ← widgets de progreso M3E

```

**Reglas de paquetes locales:**
- Cada paquete tiene `pubspec.yaml`, `LICENSE-MIT`/`NOTICE` y `lib/`.
- `publish_to: 'none'`.
- Se referencian desde `pubspec.yaml` con `path:`.
- **Nunca** se copia código de un paquete a `lib/`. Si una app necesita
  un paquete, se importa. Si un widget sirve para 2+ paquetes, se
  promueve al paquete correcto, no se duplica.

---

## 3. Regla de `core/`

`core/` contiene **solo** configuración, constantes, formateadores y
helpers puros que no encajan en ninguna otra capa.

**Sí va en `core/`:**
- `app_theme.dart` (construcción del `ThemeData`)
- `seed_palette.dart` (constantes de color)
- Formateadores de fecha puros
- Constantes de layout compartidas (si alguna vez las hay)

**No va en `core/`:**
- Modelos de dominio (`AppRelationship`, `AppSettings`) → `providers/`
- Providers → `providers/`
- Pantallas → `screens/`
- Widgets → `widgets/`

`core/` **no es un basurero**. Si dudas, no va en `core/`.

---

## 4. Regla de promoción temprana de widgets

**Criterio:** si un widget privado (`_Xxx`) tiene **uso probable en
otra pantalla en el corto plazo**, se promueve a `widgets/` **en el
mismo commit** donde se crea. No se espera al segundo uso real.

**Por qué:** un widget privado duplicado en dos pantallas es peor que
un widget público que solo se usa en una. La duplicación por olvido es
el error más caro de refactorizar después.

**Se queda privado cuando:**
- Solo tiene sentido en esa pantalla.
- Está fuertemente acoplado a un dominio específico (ej.
  `_MemberField` con prefijo A/B/C).
- No hay un segundo uso plausible en los próximos 2-3 commits.

**Nomenclatura de archivos en `widgets/`:**
- Un widget por archivo: `nombre_widget.dart`.
- Nombre de archivo en snake_case con sufijo por rol:
  `*_card.dart`, `*_button.dart`, `*_chip.dart`, `*_preview.dart`,
  `*_selector.dart`, `*_header.dart`.
- Clase: `PascalCase`.

**Cuando un archivo de `widgets/` agrupa varios widgets pequeños
relacionados** (ej. `settings_components.dart` con `MiniChip`,
`PillStatus`, `TonalIconBubble`, `BentoCard`), se llama
`*_components.dart`. Es la **excepción** para utilidades de UI muy
pequeñas que se usan juntas. Widgets con cuerpo propio van a su
archivo.

**Ejemplos de la decisión aplicada:**
- `TonalBackButton` → extraído por duplicación entre 2 pantallas.
- `ShapeSelectorCard` → extraído por reuso probable en selector de
  iconos.
- `AnniversaryCard` → extraído porque Home lo va a usar.
- `DangerActionCard` → extraído porque "borrar cuenta" y "borrar todo"
  van a usar el mismo patrón.
- `_AmoledCard` → privado, específico de Appearance.
- `_MemberField` → privado, específico de Relationship.

---

## 5. Regla de pantallas delgadas

Ninguna `*_screen.dart` debe superar ~150 líneas. Su responsabilidad:
1. Leer estado (`ref.watch` / `ref.read`).
2. Componer widgets de `widgets/` en un `CustomScrollView` o
   `ListView`.
3. Navegar a subpantallas.

**No hace en la screen:**
- Lógica de negocio compleja.
- Cálculos de fecha, texto o duración (van a `widgets/` o `core/`).
- Widgets de UI con cuerpo propio (`_FooCard` de 80 líneas se extrae).

**Si una screen crece**, extrae a `widgets/` sin preguntar.

---

## 6. Regla de scroll

**Pestañas del shell** (Inicio, Calendario, Mensajes, Juegos):
intentan caber sin scroll en 360×800 dp. Si no caben, se reduce,
agrupa o justifica scroll.

**Rutas push** (Ajustes, Tema y color, Datos de la relación, Acerca
de, subpantallas futuras): **scroll libre**. Usar
`CustomScrollView` + `SliverList` con `BouncingScrollPhysics`.

**Motivo:** las pestañas se ven todo el tiempo; las subpantallas son
navegación profunda donde el scroll es esperado.

**No proponer "reducir para que quepa" en rutas push.** No aplica.

---

## 7. Regla de `SliverAppBar.large`

Para headers grandes en pantallas push:

- **Sí:** `SliverAppBar.large(title: Text(...))` y dejar que M3 maneje
  el fade entre título expandido y colapsado.
- **No:** `flexibleSpace: FlexibleSpaceBar(title: Text(...))` custom
  con `displaySmall`. **Rompe el fade automático**: al hacer scroll,
  el `Text` custom se queda visible y se encima con el título chico
  del AppBar. Bug visual real, visto y corregido.

Si el tamaño del título expandido (M3 lo pone en `headlineMedium`) no
basta, la alternativa es un `AnimationController` propio con
`ScrollController` escuchando el offset. Se evalúa solo si hace falta.

---

## 8. Regla de nulabilidad con Riverpod

En `ConsumerWidget` / `ConsumerStatefulWidget`, cuando se mezcla un
parámetro nullable con `ref.watch` usando `??`:

**Sí hacer:**
```dart
final AppRelationship fromProvider = ref.watch(relationshipProvider);
final AppRelationship rel =
    (relationship ?? fromProvider) as AppRelationship;

if (variant == RelationshipCardVariant.hero) {
  return _HeroCard(relationship: rel, ...);
}
return _CompactCard(relationship: rel, ...);
```

No hacer:

```dart
final rel = relationship ?? ref.watch(relationshipProvider);
return switch (variant) {                     // ERROR de nulabilidad
  RelationshipCardVariant.hero => _HeroCard(relationship: rel, ...),
  RelationshipCardVariant.compact => _CompactCard(relationship: rel, ...),
};
```

Por qué: el switch expression de Dart 3.13 pierde la promoción
de non-null a través del ??. Incluso final AppRelationship rel = ...
e if/else fallan a veces. El cast as T es el cinturón definitivo.

Regla de diagnóstico: si un error de nulabilidad persiste después
de 2 intentos, aislar cada paso del ?? en variables con tipo
explícito para que el error apunte a la línea exacta donde se rompe.

Parámetros de widgets internos siempre T (no T?). La
nulabilidad se resuelve antes de pasarlos, en el widget público.

---

9. Regla de idioma (UI)

· Sentence case en toda la UI: "Datos de la relación", no "Datos
  De La Relación".
· Español mexicano o neutro. Evitar castellanismos:
  · "agrega" (no "añade")
  · "elimina" (no "borra")
  · "celular" (no "móvil")
  · "computadora" (no "ordenador")
  · "archivo" (no "fichero")
  · "presionar/tocar" (no "pulsar")
  · "ustedes" (no "vosotros")
  · "elegir/seleccionar" (no "coger")
· Tildes correctas: "Hétero" (no "Hetero").
· "Relación" en UI, nunca "pareja" (la app soporta 2+ miembros).
  En código, los archivos usan relationship_*.
· "Poliamor" en UI para polyamorous. No "Trio" (suena sexual)
  ni "Trieja".
· No usar "backlog" en conversación; decir "pendientes" o "lo
  anotado".

---

10. Regla de los MD

Los archivos .md (ARQUITECTURA.md, ESTADO.md, PENDIENTES.md,
sesion-*.md) no se tocan durante la sesión de trabajo. Se
actualizan en un commit único al cierre de la sesión.

Motivo: evitar commits intermedios de docs que interrumpen el
flujo de builds y dificultan el diff.

Si durante la sesión surge una regla nueva, se acumula mentalmente y
se escribe al cierre.

---

11. Regla de versionado

· pubspec.yaml del repo queda siempre en version: 1.0.0+1.
  Nunca se actualiza a mano.
· El workflow build.yml reemplaza la versión antes de compilar
  con 0.1.${github.run_number}+${github.run_number}.
· github.run_number cuenta todas las ejecuciones, exitosas o
  fallidas. Es lo que queremos: cada intento es una build distinta.
· La app lee su versión real desde package_info_plus, nunca
  hardcodeada.
· No hay commits automáticos desde CI. El pubspec.yaml del repo
  no se toca por el workflow.

---

12. Regla de paquetes externos

Antes de agregar un paquete de pub.dev:

1. ¿Ya hay algo en packages/ que lo resuelva?
2. ¿Se puede hacer en ~150 líneas de Flutter puro?
3. ¿El paquete declara compatibilidad con Flutter 3.47.7 y Dart 3.13?

Si las 3 respuestas son "no" → se agrega.

Preferencia por paquetes locales cuando el paquete resuelve un
problema del dominio (formas, progreso) y hay código propio que lo
envuelve. Se copia a packages/ y se referencia con path:.

Paquetes aprobados hoy: shared_preferences, flutter_riverpod,
package_info_plus, m3e_shapes (local), m3e_progress (local),
androidx_graphics_shapes (transitivo de m3e_shapes).

Paquetes descartados explícitamente:

· animations (transiciones): se resuelven con PageRouteBuilder
  casero.

---

13. Regla de transiciones entre pantallas

Todas las navegaciones push desde un hub usan la transición orgánica
definida en settings_screen.dart:

```dart
PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 320),
  reverseTransitionDuration: const Duration(milliseconds: 240),
  pageBuilder: (_, __, ___) => screen,
  transitionsBuilder: (_, animation, __, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
        child: child,
      ),
    );
  },
);
```

No usar MaterialPageRoute desde hubs. Si la transición se repite
en 3+ pantallas, se extrae a core/navigation.dart como helper
openOrganic(context, screen).

---

14. Backend — pendiente de diseño

Ver tools/PENDIENTES.md ítems 1 y 2. Se abordan cuando se decida
backend, identidad y modelo de borrado criptográfico. No se improvisa.

---

Resumen para un agente nuevo

Si un agente lee solo este documento, debe saber:

1. Cualquier widget con reuso probable va a widgets/ en el mismo
   commit, no se espera al 2º uso.
2. Las screens no superan 150 líneas. Si crecen, se extrae.
3. Las rutas push scrollean libremente; las pestañas del shell,
   no.
4. No usar flexibleSpace custom en SliverAppBar.large.
5. No usar switch expression con ?? de providers.
6. Los MD se tocan al cierre de sesión, no durante.
7. La versión la maneja el workflow, no el pubspec.yaml del
   repo.
8. Los paquetes locales viven en packages/, se referencian con
   path:.
9. Idioma: español mexicano/neutro, sentence case, "Relación" no
   "pareja", "Poliamor" no "Trio", "Hétero" con tilde.