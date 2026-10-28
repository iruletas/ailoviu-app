# ESTADO DEL PROYECTO

_Última actualización: 2026-10-28_

## Fase actual

**Fase 1 cerrada.** Shell + Ajustes + Relación + Apariencia + About
en M3E.
**Bloque A (infra de auth) cerrado.** Auth biométrica, PIN fallback,
app-lock, feature-lock, SecurityScreen funcional.

Próximo: **Bloque B — Home real + Estados**.

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

## 🔜 Siguiente (Bloque B)

1. **Home real**:
   - `RelationshipPreview` o `RelationshipSummaryCard(hero)` como hero.
   - `AnniversaryBadge` (días juntos).
   - Slot para próximo día especial (requiere Calendario futuro).
   - **Estados**: editor de estado corto (texto/emoji), persistido en
     `SecureStore`, mostrado en Home con "vistazo rápido".
   - Una acción única (Jugar, o Escribir estado).
2. **`calendar_screen.dart`** real.
3. **`connection_screen.dart`** real (mensajes).
4. **`play_screen.dart`** real.
5. **`FeatureGate`** wrapper (cuando llegue la primera feature
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