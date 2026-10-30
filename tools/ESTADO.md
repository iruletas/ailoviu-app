# ESTADO DEL PROYECTO

_Última actualización: 2026-10-29_

## Fase actual

**Fase 1 cerrada.** Shell + Ajustes + Relación + Apariencia + About en M3E.
**Bloque A (infra de auth) cerrado.** Auth biométrica, PIN fallback, app-lock, feature-lock, SecurityScreen funcional.
**Bloque B (infra de sync y juegos) cerrado.** E2EE, Firebase, servicio en primer plano, modelos de juegos, auto-versionado y compilación estable.
**Bloque C (Hogar v1) cerrado.** Mapa interactivo, estados, días juntos, buzz, placeholders. Renombres de pestañas.

Próximo: **Bloque D — UI de Sync (Onboarding, QR) + Nosotros hub**.

## ✅ Hecho

### Fase 0 — Configuración base
- [x] Repo público `ailoviu-app` creado.
- [x] Estructura limpia de Flutter.
- [x] `AndroidManifest.xml` y `MainActivity.kt` con `com.iruletas.ailoviu`.
- [x] Workflow `build.yml` con Artifacts, limpieza automática y caché de Gradle.
- [x] Keystore generado, guardado en Secrets y configurado para firmar la APK.
- [x] APK firmada descargada e instalada en el celular.

### Fase 1 — Shell + Ajustes + Relación
(Navbar pill flotante, SettingsScreen, AppearanceScreen, RelationshipScreen, AboutScreen, providers, `packages/m3e_shapes` integrado.)

### Bloque A — Infraestructura de auth
(AuthService con local_auth + PIN fallback, AppAuthSettings, PrivateFeatureLock, AuthSession, AuthGate, PinPad, PinSetupScreen, LockScreen, SecurityScreen.)

### Bloque B — Infraestructura de Sync y Juegos
(E2EE, FirebaseTransport, SyncService, BackgroundSyncService, GameSession, GameDefinition, LocalGameService.)

---

### Bloque C — Hogar v1 (cerrado 2026-10-29)

#### Renombres y estructura de navegación
- [x] `calendar_screen.dart` → `days_screen.dart` (pestaña "Días").
- [x] `connection_screen.dart` → `us_screen.dart` (pestaña "Nosotros").
- [x] `play_screen.dart` → `games_screen.dart` (pestaña "Juegos").
- [x] `main_shell.dart` actualizado: Hogar / Días / Nosotros / Juegos, con íconos nuevos.

#### Archivos nuevos (Modelos y Providers)
- [x] `lib/models/home_models.dart` — `PartnerStatus`, `PartnerLocation`, `LocationsSnapshot`, `BuzzState`, `DistanceConfig`.
- [x] `lib/providers/home_providers.dart` — `myDeviceIdProvider`, `myStatusProvider`, `statusesProvider`, `locationsProvider`, `buzzProvider`, `distanceProvider`.

#### Archivos nuevos (Servicios)
- [x] `lib/services/device_identity_service.dart` — genera y persiste el UUID del dispositivo (Keystore).
- [x] `lib/services/location_service.dart` — `ensurePermission()`, `getCurrentLocation()`, `backgroundUpdates()`. Chequea permisos antes de re-pedir.

#### Archivos nuevos (Core y Widgets)
- [x] `lib/core/map_style.dart` — matriz de color para `ColorFiltered`, URL de OSM, zoom y línea de distancia.
- [x] `lib/widgets/home_map_hero.dart` — mapa `flutter_map`, avatares squircle, líneas de distancia, botón de compartir ubicación (con manejo de permisos), `ColorFiltered` para estilo limpio.
- [x] `lib/widgets/buzz_button.dart` — cooldown 30s, límite 50/día, toast flotante, jitter shake.
- [x] `lib/widgets/days_together_card.dart` — cifra grande, latido del corazón, badges de aniversario/hito, tono rosa.
- [x] `lib/widgets/next_event_card.dart` — placeholder con modal M3E.
- [x] `lib/widgets/menstruation_preview_card.dart` — placeholder con modal M3E y tono rojo.
- [x] `lib/widgets/status_editor_sheet.dart` — texto libre, máx 60 chars, sin selector de emojis, botón de borrar explícito.

#### Archivos modificados
- [x] `lib/screens/home_screen.dart` — dashboard con `IntrinsicHeight`, `SliverToBoxAdapter`, mapa, tarjetas, buzz.
- [x] `android/app/src/main/AndroidManifest.xml` — permisos de ubicación foreground + background.
- [x] `pubspec.yaml` — `flutter_map`, `latlong2`, `geolocator`.

#### Bugs resueltos
- [x] `prefs_provider.dart` importaba `services/secure_store.dart` en vez de `core/secure_store.dart`. Build roto.
- [x] `home_map_hero.dart` se envió incompleto (faltaba el cierre). Compilación rota.
- [x] `LocationService` pedía permisos de nuevo y fallaba por el bug de Android al re-pedir un permiso ya concedido. Ahora usa `ensurePermission()` que chequea primero.
- [x] `myDeviceIdProvider` dependía de `SyncService` (que no se inicializa sin pareja). Se movió a `DeviceIdentityService`, que crea el UUID desde el primer arranque.
- [x] El estado no se podía borrar sin eliminar todas las letras. Se agregó botón de basura explícito.
- [x] El indicador de estado no aparecía en el mapa. Ahora `_buildAvatarsLayer` lee `myStatusProvider` y `statusesProvider`.
- [x] El mapa se veía muy crema. Se agregó `ColorFiltered` con matriz de brillo/saturación.
- [x] El toast del buzz se salía de pantalla. Ahora aparece a la derecha del botón.

#### Decisiones tomadas
- [x] **Mapa con `flutter_map` (OSM)**, no Google Maps (evita API key y facturación).
- [x] **Estilo del mapa**: `ColorFiltered` para un look limpio y blanco.
- [x] **Estado sin emojis**: se eliminó el selector de chips. Los emojis se escriben directo en el texto.
- [x] **`IntrinsicHeight` en la fila Bento**: para que las dos cards tengan la misma altura.
- [x] **`SliverToBoxAdapter`** en vez de `SliverList` para los bloques del dashboard.
- [x] **`SafeArea(bottom: false)` en Hogar**, para no duplicar el padding del shell.
- [x] **`BuzzButton` vive en `home_screen.dart`** por ahora. Se moverá al shell cuando exista la UI de sync.

---

## 🔜 Siguiente (Bloque D)

1. **UI de Sync**:
   - `onboarding_transport_screen.dart` (pegar `google-services.json` y validar).
   - `pairing_screen.dart` (QR de emparejamiento, intercambio de llaves X25519).
   - `sync_settings_screen.dart` (estado del sync, forzar sync, toggle del servicio en primer plano).
   - Conectar `BuzzNotifier.tryBuzz` a `syncServiceProvider.enqueue`.
   - Conectar el envío de ubicaciones al sync.
2. **Nosotros hub**: grid de 12 features (Diario, Cartas, Estados, Galería, Música, Recuerdos, Sueños, Zumbidos, Mapa, Sólo escucha, Listas de deseos, Ideas para citas).
3. **Días real**: línea de tiempo con eventos.
4. **Juegos**: primer juego local (Ruleta).

## 🐛 Bugs abiertos
- (ninguno)

---

## Instrucción explícita para la IA: archivos completos

Al proponer cambios de código, entregar **siempre el archivo completo**, no fragmentos ni diffs por bloques. El usuario no edita archivos por partes: copia y pega el archivo entero.

## Instrucción explícita para la IA: entorno del desarrollador

El usuario trabaja **100% desde el celular**, sin PC ni terminal.
Todo el ciclo de compilación ocurre en GitHub Actions. Cada build
cuesta 5-10 min de CI. Entregar archivos completos siempre.

## Instrucción explícita para la IA: idioma y estilo

- Sentence case, español mexicano/neutro.
- "Relación", nunca "pareja". "Hétero" con tilde. "Poliamor" sin "Trio".
- No usar "backlog".

## Instrucción explícita para la IA: pantallas sin scroll

La regla "sin scroll" aplica **solo a pestañas del shell**. Rutas push scrollean libremente.

## Instrucción explícita para la IA: regla de los MD

Los `.md` no se tocan durante la sesión. Se actualizan en un commit único al cierre.