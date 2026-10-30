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
- Persistencia local: `shared_preferences` 2.x
- Cifrado local: `flutter_secure_storage` 9.x (Keystore Android)
- Info del bundle: `package_info_plus` 8.x
- Auth del dispositivo: `local_auth` 2.x (huella, PIN o patrón)
- Hashing local: `crypto` 3.x (SHA-256 para PIN fallback)
- Formas M3E: `m3e_shapes` (paquete local en `packages/`)
- Progreso M3E: `m3e_progress` (paquete local, aún sin integrar)
- Sync: `firebase_core`, `firebase_database`, `firebase_messaging`, `firebase_storage`
- Criptografía E2EE: `cryptography` 2.x (X25519, AES-GCM, HKDF)
- Utilidades: `uuid`, `collection`
- Servicio en segundo plano: `flutter_foreground_task` 11.x
- Emparejamiento y share: `qr_flutter`, `mobile_scanner`, `share_plus`
- Juegos locales: `nearby_connections` 4.x
- Mapa: `flutter_map` 7.x, `latlong2` 0.9.x
- Ubicación: `geolocator` 13.x
- CI/CD: GitHub Actions · ubuntu-24.04 · Java 17
- Firma: keystore `.jks` inyectado por Base64 en Secrets
- Versionado: **automático por `run_number` en `build.yml`** (ver regla 11)

---

## 2. Estructura de carpetas

### `lib/` — organización por capa, plana

```

lib/
├── main.dart              ← runApp, nada más
├── app.dart               ← MaterialApp + tema + AuthGate
├── core/                  ← config transversal (ver regla 3)
├── models/                ← clases de datos, sin lógica
├── services/              ← lógica sin estado, sin UI
├── providers/             ← estado global (Riverpod)
├── screens/               ← pantallas
├── widgets/               ← widgets reutilizables (ver regla 4)
└── games/                 ← dominio de juegos (contratos y lógica)

```

### Regla de sufijo → carpeta (obligatoria)

Un archivo se ubica según **el sufijo de su nombre**, sin excepciones:

| Sufijo en el nombre     | Carpeta destino |
|-------------------------|-----------------|
| `*_models.dart`         | `lib/models/`       |
| `*_providers.dart`      | `lib/providers/`    |
| `*_service.dart`        | `lib/services/`     |
| `*_screen.dart`         | `lib/screens/`      |
| `*_card.dart`, `*_chip.dart`, `*_button.dart`, etc. | `lib/widgets/` |
| `*_components.dart`     | `lib/widgets/` (excepción: agrupa varios widgets pequeños) |

**Sin sufijo reconocible** → se evalúa caso por caso:
- `main.dart`, `app.dart` → raíz de `lib/`.
- `app_theme.dart`, `seed_palette.dart`, `map_style.dart` → `lib/core/`.
- `game_definition.dart`, `game_session.dart` → `lib/games/` (son dominio, no caben en core).
- Si dudas, **no va a `core/`** (regla 3 sigue aplicando).

**Consecuencias duras:**
- Los modelos **nunca** viven dentro de un `*_providers.dart`. Se extraen a `models/`. El provider los `export` para no romper a los consumidores.
- Los providers **nunca** viven en `core/` ni en `services/`.
- Los services **nunca** viven en `core/` ni en `providers/`.
- Si un archivo tiene dos roles, **se parte en dos archivos** con el sufijo correcto.

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
- **Nunca** se copia código de un paquete a `lib/`. Si una app necesita un paquete, se importa.

---

## 3. Regla de `core/`

`core/` contiene **solo** configuración, constantes y helpers puros que no encajan en ninguna otra capa. Proveedores de Riverpod **no** van en `core/` (regla 2, sufijo → carpeta).

**Sí va en `core/`:**
- `app_theme.dart` (construcción del `ThemeData`)
- `seed_palette.dart` (constantes de color)
- `secure_store.dart` (wrapper de `flutter_secure_storage`)
- `map_style.dart` (paleta y matriz de color del mapa)

**No va en `core/`:**
- Modelos de dominio → `models/`
- Providers → `providers/`
- Services → `services/`
- Pantallas → `screens/`
- Widgets → `widgets/`
- Contratos de juegos → `games/`

`core/` **no es un basurero**. Si dudas, no va en `core/`.

---

## 4. Regla de promoción temprana de widgets

**Criterio:** si un widget privado (`_Xxx`) tiene **uso probable en otra pantalla**, se promueve a `widgets/` **en el mismo commit** donde se crea. No se espera al segundo uso real.

**Se queda privado cuando:**
- Solo tiene sentido en esa pantalla.
- Está fuertemente acoplado a un dominio específico.
- No hay un segundo uso plausible.

**Nomenclatura:**
- Un widget por archivo: `nombre_widget.dart`.
- Nombre en snake_case con sufijo por rol: `*_card.dart`, `*_button.dart`, `*_chip.dart`, `*_preview.dart`, `*_selector.dart`, `*_header.dart`, `*_gate.dart`.
- Clase: `PascalCase`.

**Excepción `*_components.dart`:** agrupa varios widgets pequeños relacionados (`MiniChip`, `PillStatus`, `TonalIconBubble`, `BentoCard`). Es la excepción para utilidades de UI muy pequeñas que se usan juntas.

---

## 5. Regla de pantallas delgadas

Ninguna `*_screen.dart` debe superar ~150 líneas. Su responsabilidad:
1. Leer estado (`ref.watch` / `ref.read`).
2. Componer widgets de `widgets/` en un `CustomScrollView` o `ListView`.
3. Navegar a subpantallas.

**No hace en la screen:** lógica de negocio compleja, cálculos de fecha/texto/duración, widgets de UI con cuerpo propio (`_FooCard` de 80 líneas se extrae). **Si una screen crece, extrae a `widgets/` sin preguntar.**

---

## 6. Regla de scroll

**Pestañas del shell** (Hogar, Días, Nosotros, Juegos): intentan caber sin scroll en 360×800 dp. Si no caben, scrollean, pero **sin** `SliverAppBar.large` (no aplica a pestañas).

**Rutas push** (Ajustes, Tema y color, Datos de la relación, Acerca de, Seguridad, Crear PIN): **scroll libre** con `CustomScrollView` + `SliverList` + `BouncingScrollPhysics`.

---

## 7. Regla de `SliverAppBar.large`

- **Sí:** `SliverAppBar.large(title: Text(...))` y dejar que M3 maneje el fade.
- **No:** `flexibleSpace: FlexibleSpaceBar(title: Text(...))` custom con `displaySmall`. **Rompe el fade automático.**

---

## 8. Regla de nulabilidad con Riverpod

Cuando se mezcla un parámetro nullable con `ref.watch` usando `??`:

**Sí hacer:**
```dart
final AppRelationship fromProvider = ref.watch(relationshipProvider);
final AppRelationship rel =
    (relationship ?? fromProvider) as AppRelationship;
```

No hacer: switch expression con ?? de providers (el analyzer pierde la promoción a non-null).

Regla extra: cuando uses ref.read(provider.future) o ref.watch(provider) y vayas a llamar métodos sobre el resultado, importa explícitamente el archivo que define el tipo. Sin el import, Dart cae a Object? en silencio y los métodos no resuelven.

---

9. Regla de idioma (UI)

· Sentence case en toda la UI: "Datos de la relación", no "Datos De La Relación".
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
· "Relación" en UI, nunca "pareja".
· "Poliamor" en UI, nunca "Trio" ni "Trieja".
· No usar "backlog" en conversación; decir "pendientes".

---

10. Regla de los MD

Los archivos .md (ARQUITECTURA.md, ESTADO.md, PENDIENTES.md, sesion-*.md) no se tocan durante la sesión de trabajo. Se actualizan en un commit único al cierre de la sesión.

Motivo: evitar commits intermedios de docs que interrumpen el flujo de builds.

---

11. Regla de versionado

· pubspec.yaml del repo se queda con la versión estática (ej. 0.1.0+1). No se sube a mano al cerrar el bloque.
· El workflow build.yml auto-versiona antes de compilar:
  ```yaml
  VERSION="0.1.${{ github.run_number }}"
  sed -i -E "s/^version: .*/version: ${VERSION}+${{ github.run_number }}/" pubspec.yaml
  ```
· Convención de la versión en el APK: 0.1.{run_number}+{run_number}.
· La app lee su versión real desde package_info_plus (vía app_info_providers.dart), nunca hardcodeada.
· No hay commits automáticos desde CI (excepto el reorganize.yml manual).

---

12. Regla de paquetes externos

Antes de agregar un paquete de pub.dev:

1. ¿Ya hay algo en packages/ que lo resuelva?
2. ¿Se puede hacer en ~150 líneas de Flutter puro?
3. ¿El paquete declara compatibilidad con Flutter 3.47.7 y Dart 3.13?

Si las 3 respuestas son "no" → se agrega.

Paquetes aprobados hoy: shared_preferences, flutter_riverpod, package_info_plus, local_auth, crypto, flutter_secure_storage, firebase_core, firebase_database, firebase_messaging, firebase_storage, cryptography, uuid, collection, flutter_local_notifications, flutter_foreground_task, qr_flutter, mobile_scanner, share_plus, nearby_connections, flutter_map, latlong2, geolocator, m3e_shapes (local), m3e_progress (local), androidx_graphics_shapes (transitivo).

Paquetes descartados explícitamente:

· animations: se resuelve con PageRouteBuilder casero.
· libsignal_protocol_dart: se descartó por falta de mantenimiento. Se usa cryptography para hacer X25519 + AES-GCM estático.
· google_maps_flutter: se descartó por requerir API key y cuenta de facturación. Se usa flutter_map + OSM.

---

13. Regla de transiciones entre pantallas

Todas las navegaciones push desde un hub usan _openOrganic de settings_screen.dart (PageRouteBuilder con fade + scale 0.96→1.0, easeOutCubic).

Si la transición se repite en 3+ pantallas, se extrae a core/navigation.dart como helper openOrganic(context, screen).

---

14. Regla de auth

· Método principal: local_auth del sistema operativo. El sistema muestra los métodos que el usuario tenga configurados (huella, PIN, patrón, contraseña).
· Fallback: PIN propio de la app, solo cuando el dispositivo no tiene bloqueo de pantalla.
· App-lock y feature-lock son independientes. App-lock pide auth al abrir y respeta un timeout de background. Feature-lock pide auth al entrar a una sección privada y no tiene timeout: al salir se re-bloquea.
· Sin métodos configurados + bloqueo activo es un estado inconsistente: la UI debe mostrar CTA explícito "Configurar PIN".
· AuthGate es app-level. Para features privadas se usará un FeatureGate (aún no existe).
· Las claves (PIN hash, salt, secretos del ratchet) viven en KeyStore (Keystore Android), no en SharedPreferences.

---

15. Regla de Sync y Criptografía

· El transporte por defecto es Firebase Realtime Database. Cada pareja configura su propio proyecto de Firebase.
· La app funciona local-only si no hay transporte configurado.
· La criptografía es E2EE usando X25519 para derivar el secreto compartido y AES-GCM para el contenido.
· El transporte (Firebase) solo ve blobs cifrados.
· El servicio en segundo plano (flutter_foreground_task) mantiene la conexión y las notificaciones con la app cerrada.
· Device Identity: el deviceId es un UUID generado localmente y guardado en Keystore (DeviceIdentityService). No depende de que haya pareja emparejada.

---

16. Regla de Ubicación

· Usamos geolocator + flutter_map (OpenStreetMap).
· El permiso de ubicación es foreground por defecto. Background (ACCESS_BACKGROUND_LOCATION) se pide solo si el usuario lo activa explícitamente.
· Las ubicaciones se comparten por sync cifrado (Firebase solo ve el blob).
· El LocationService nunca debe llamar requestPermission() sin chequear antes checkPermission(): Android devuelve denied al re-pedir un permiso ya concedido.

---

Resumen para un agente nuevo

1. Cualquier widget con reuso probable va a widgets/ en el mismo commit, no se espera al 2º uso.
2. Los archivos van a su carpeta por sufijo (*_models → models/, *_providers → providers/, *_service → services/).
3. Las screens no superan 150 líneas. Si crecen, se extrae.
4. Las rutas push scrollean libremente; las pestañas del shell, no.
5. No usar flexibleSpace custom en SliverAppBar.large.
6. No usar switch expression con ?? de providers. Cuando un provider devuelve un tipo y le llamas métodos, importa el archivo del tipo.
7. Los MD se tocan al cierre de sesión, no durante.
8. La versión en pubspec.yaml NO se toca a mano. El workflow auto-versiona con run_number.
9. Auth: local_auth primero, PIN fallback solo si no hay bloqueo de pantalla. App-lock y feature-lock independientes.
10. Idioma: español mexicano/neutro, sentence case, "Relación" no "pareja", "Poliamor" no "Trio", "Hétero" con tilde.
11. Sync: Firebase + E2EE estático (X25519 + AES-GCM). Sin servidor propio.
12. DeviceIdentityService crea el deviceId independientemente de SyncService.
13. LocationService: checkPermission antes de requestPermission para evitar el bug de Android.