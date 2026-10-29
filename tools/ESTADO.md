# ESTADO DEL PROYECTO

_Última actualización: 2026-10-28_

## Fase actual

**Fase 1 cerrada.** Shell + Ajustes + Relación + Apariencia + About
en M3E.
**Bloque A (infra de auth) cerrado.** Auth biométrica, PIN fallback,
app-lock, feature-lock, SecurityScreen funcional.
**Bloque B (infra de sync y juegos) cerrado.** E2EE, Firebase, servicio
en primer plano, modelos de juegos, auto-versionado y compilación estable.

Próximo: **Bloque C — UI de Sync (Onboarding, QR, Ajustes) + Home real**.

## ✅ Hecho

### Fase 0 — Configuración base
- [x] Repo público `ailoviu-app` creado.
- [x] Estructura limpia de Flutter.
- [x] `AndroidManifest.xml` y `MainActivity.kt` con
      `com.iruletas.ailoviu`.
- [x] Workflow `build.yml` con Artifacts, limpieza automática y caché
      de Gradle.
- [x] Keystore generado, guardado en Secrets y configurado para firmar
      la APK.
- [x] APK firmada descargada e instalada en el celular.

### Fase 1 — Shell + Ajustes + Relación
(Se mantiene lo listado en la sesión 2026-10-27: navbar pill flotante,
SettingsScreen, AppearanceScreen, RelationshipScreen, AboutScreen,
providers, packages/m3e_shapes integrado.)

### Bloque A — Infraestructura de auth (cerrado 2026-10-28)

#### Archivos nuevos
- [x] `lib/models/auth_models.dart` — `AppAuthSettings`,
      `PrivateFeatureLock`, `AuthSession`.
- [x] `lib/models/settings_models.dart` — `AppSettings` (extraído).
- [x] `lib/models/relationship_models.dart` — `AppRelationship`,
      `RelationshipType` (extraídos).
- [x] `lib/services/auth_keys.dart` — claves de persistencia +
      `PrivateFeatures`.
- [x] `lib/services/auth_service.dart` — `AuthService` con
      `authenticateWithSystem` + `setAppPin`/`verifyAppPin`/`clearAppPin`
      (SHA-256 + salt).
- [x] `lib/providers/prefs_provider.dart` — `prefsProvider` +
      `SecureStore` + `secureStoreProvider`.
- [x] `lib/providers/auth_settings_providers.dart` —
      `authSettingsProvider`, `featureLocksProvider`, `authSessionProvider`.
- [x] `lib/widgets/auth_gate.dart` — gate app-level con lifecycle
      observer y re-bloqueo por timeout.
- [x] `lib/screens/pin_pad.dart` — teclado con dots escalados, shake
      en error, backspace reactivo, háptica progresiva.
- [x] `lib/screens/pin_setup_screen.dart` — flujo de 2 pasos con
      stepper, hero que morph, error capsule, saving indicator.
- [x] `lib/screens/lock_screen.dart` — hero reactivo por modo,
      AnimatedSwitcher entre system/pin/unavailable/error,
      `layoutBuilder` para evitar ghost icons, burst de éxito.
- [x] `lib/screens/security_screen.dart` — toggle app-lock + timeout
      pills + tarjeta de método reactiva al estado efectivo de
      protección + bloqueo por función.

#### Archivos modificados
- [x] `lib/app.dart` — `AuthGate` envuelve `MainShell`.
- [x] `lib/screens/settings_screen.dart` — nueva fila "Seguridad" con
      ícono dinámico y subtítulo animado.
- [x] `lib/providers/settings_providers.dart` — migrado a
      `prefsProvider`, `export` de `settings_models`.
- [x] `lib/providers/relationship_providers.dart` — `export` de
      `relationship_models`.
- [x] `android/app/src/main/kotlin/com/iruletas/ailoviu/MainActivity.kt`
      — `FlutterFragmentActivity` (requerido por `local_auth`).
- [x] `android/app/src/main/AndroidManifest.xml` — permisos
      `USE_BIOMETRIC` y `USE_FINGERPRINT` (`maxSdkVersion=27`).
- [x] `pubspec.yaml` — `local_auth: ^2.3.0`, `crypto: ^3.0.0`.

#### Workflow
- [x] `build.yml` — inyección de `minSdk = maxOf(flutter.minSdkVersion, 23)`
      para `local_auth`.
- [x] `build.yml` — **eliminado** el auto-versionado por `run_number`.
      Ahora solo verifica `grep "^version:" pubspec.yaml` y compila.

#### Bugs resueltos
- [x] `Curves.backOut` no existe → `Curves.easeOutBack`.
- [x] `AuthSession`/`AppAuthSettings` no encontrados en `auth_gate`
      → import explícito de `models/auth_models.dart`.
- [x] `AuthService` no tipado en `security_screen` → import explícito
      de `services/auth_service.dart`.
- [x] `systemAuthAvailable` siempre `false` → `AuthSettingsNotifier._load()`
      hace `LocalAuthentication().isDeviceSupported()` real.
- [x] Salto de texto entre pasos de PIN → `SizedBox(height: 72)` fijo.
- [x] Fingerprint dibujado detrás del PinPad → `layoutBuilder`
      (current only) + `ColoredBox` opaco.
- [x] "Cambiar PIN" inaccesible cuando sistema disponible → tarjeta
      reestructurada con fila de PIN de respaldo + Cambiar/Quitar.
- [x] Tarjeta de método siempre parecía activa → `_OffMethodCard`
      neutra cuando `appLockEnabled == false` y `anyFeatureLocked == false`.

#### Reglas nuevas en `ARQUITECTURA.md`
- [x] Sufijo → carpeta obligatorio.
- [x] Versionado manual al cierre, sin `run_number`.
- [x] Regla 14 de auth: `local_auth` primero, PIN fallback solo sin
      bloqueo de pantalla. App-lock y feature-lock independientes.
- [x] Regla 8 ampliada: importar el archivo del tipo cuando se llama
      método sobre resultado de provider.

---

### Bloque B — Infraestructura de Sync y Juegos (cerrado 2026-10-28)

#### Archivos nuevos (Modelos)
- [x] `lib/models/sync_models.dart` — `SyncEnvelope`, `SyncType`, `SyncStatus`, `TransportResult`, etc.
- [x] `lib/models/game_models.dart` — `GameSession`, `GameMove`, `GameMode`.
- [x] `lib/models/calendar_models.dart` — `CalendarEvent`, `CalendarEventType`.

#### Archivos nuevos (Servicios)
- [x] `lib/services/key_store.dart` — Wrapper de `flutter_secure_storage` (Keystore).
- [x] `lib/services/crypto_service.dart` — X25519, HKDF, AES-GCM, HMAC-SHA256.
- [x] `lib/services/sync_transport.dart` — Interfaz abstracta.
- [x] `lib/services/firebase_transport.dart` — Implementación con RTDB (con persistencia offline y `.info/connected`).
- [x] `lib/services/transport_config.dart` — Resolución de config (Firebase o none).
- [x] `lib/services/notification_service.dart` — Notificaciones locales (con ID estable para evitar duplicados).
- [x] `lib/services/push_service.dart` — Registro de token FCM (envío real pendiente de Cloud Function).
- [x] `lib/services/sync_service.dart` — Orquestador con cola de eventos, deduplicación y ACKs.
- [x] `lib/services/background_sync.dart` — Servicio en primer plano (`flutter_foreground_task`) para recibir con la app cerrada.
- [x] `lib/services/nearby_game_service.dart` — Esqueleto para `nearby_connections` (TODOs).
- [x] `lib/services/local_game_service.dart` — Juegos de una sola pantalla.

#### Archivos nuevos (Dominio de Juegos)
- [x] `lib/games/game_definition.dart` — Contrato abstracto.
- [x] `lib/games/game_session.dart` — Wrapper con lógica de movimientos.

#### Archivos nuevos (Providers)
- [x] `lib/providers/sync_providers.dart` — `keyStoreProvider`, `cryptoServiceProvider`, `syncServiceProvider`, etc.

#### Archivos modificados
- [x] `lib/main.dart` — Inicializa `FlutterForegroundTask` y arranca `BackgroundSyncService.bootstrap()`.
- [x] `android/app/src/main/AndroidManifest.xml` — Permisos de Bluetooth, Wi-Fi, foreground service (`remoteMessaging`), recepción de boot.
- [x] `pubspec.yaml` — Nuevas dependencias (firebase, cryptography, flutter_foreground_task, etc.).

#### Configuración y Build
- [x] `android/settings.gradle.kts` — AGP 8.11.1, Kotlin 2.2.20.
- [x] `android/gradle/wrapper/gradle-wrapper.properties` — Gradle 8.14.3.
- [x] `.github/workflows/build.yml` — Reincorporado el auto-versionado con `VERSION="0.1.${{ github.run_number }}"`.
- [x] `.github/workflows/build.yml` — `flutter build apk --release --target-platform android-arm64` para evitar conflictos de firma.
- [x] `.github/workflows/build.yml` — Se eliminó el script de Python ("inyección quirúrgica") y se usa `git checkout -- android/app/build.gradle.kts` tras `flutter create`.

#### Bugs resueltos
- [x] `prefs_provider.dart` importaba `services/secure_store.dart` cuando el archivo está en `core/secure_store.dart`. Build roto.
- [x] El build fallaba porque Gradle 8.9.0 < 8.14.0 (exigido por Flutter 3.47.7).
- [x] El build fallaba porque Kotlin 2.1.0 < 2.2.20.
- [x] El build fallaba por falta de recursos (`mipmap/ic_launcher`, `style/LaunchTheme`) porque `flutter create` no se ejecutó. Ahora siempre se ejecuta y se restaura el `build.gradle.kts`.
- [x] El APK daba "paquete no válido" al instalar sobre una versión vieja (firmas conflictivas). Se solucionó desinstalando la versión vieja y compilando solo para `arm64` con `minSdk = 23`.

#### Decisiones tomadas
- [x] **Sin Double Ratchet.** Se descartó implementarlo a mano porque la complejidad y el riesgo de bugs superaban el beneficio para dos personas. Se usa X25519 (X3DH simplificado) + AES-GCM estático (secreto compartido guardado en Keystore).
- [x] **`lib/games/`** es la carpeta de dominio. `play_screen` sigue siendo la pantalla UI. Los juegos concretos (ruleta, preguntas) vivirán en `lib/games/`.
- [x] **Auto-versionado devuelto.** El workflow vuelve a usar `0.1.{run_number}` porque es más cómodo para el flujo del desarrollador.

---

## 🔜 Siguiente (Bloque C)

1. **UI de Sync**:
   - `onboarding_transport_screen.dart` (pegar `google-services.json` y validar).
   - `pairing_screen.dart` (QR de emparejamiento, intercambio de llaves X25519).
   - `sync_settings_screen.dart` (estado del sync, forzar sync, toggle del servicio en primer plano).
2. **Home real**:
   - `RelationshipPreview` o `RelationshipSummaryCard(hero)` como hero.
   - `AnniversaryBadge` (días juntos).
   - Slot para próximo día especial (requiere Calendario futuro).
   - **Estados**: editor de estado corto (texto/emoji), persistido en
     `SecureStore`, mostrado en Home con "vistazo rápido".
   - Una acción única (Jugar, o Escribir estado).
3. **`calendar_screen.dart`** real.
4. **`connection_screen.dart`** real (mensajes).
5. **`play_screen.dart`** real.
6. **`FeatureGate`** wrapper (cuando llegue la primera feature
   privada: Diario, Cartas, etc.).

## 🐛 Bugs abiertos
- (ninguno)

---

## Instrucción explícita para la IA: archivos completos

Al proponer cambios de código, entregar **siempre el archivo completo**,
no fragmentos ni diffs por bloques. El usuario no edita archivos por
partes: copia y pega el archivo entero.

Aplica a `pubspec.yaml`, cualquier `*.dart`, workflows
`.github/workflows/*.yml`, `AndroidManifest.xml`, `build.gradle.kts`,
cualquier `*.md`.

## Instrucción explícita para la IA: entorno del desarrollador

El usuario trabaja **100% desde el celular**, sin PC ni terminal.
Todo el ciclo de compilación ocurre en GitHub Actions. Cada build
cuesta 5-10 min de CI. Entregar archivos completos siempre.

## Instrucción explícita para la IA: idioma y estilo

- Sentence case, español mexicano/neutro.
- "Relación", nunca "pareja". "Hétero" con tilde. "Poliamor" sin "Trio".
- No usar "backlog".

## Instrucción explícita para la IA: pantallas sin scroll

La regla "sin scroll" aplica **solo a pestañas del shell**. Rutas push
scrollean libremente.

## Instrucción explícita para la IA: regla de los MD

Los `.md` no se tocan durante la sesión. Se actualizan en un commit
único al cierre.