# ESTADO DEL PROYECTO

_Última actualización: 2026-10-27_

## Fase actual
**Fase 1 cerrada.** Shell + Ajustes + Relación + Apariencia + About
todas rediseñadas en M3E.

Próxima: **Fase 2 — Home real**.

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

### Fase 1 — Shell + Ajustes + Relación (cerrada 2026-10-27)

#### Navegación y shell
- [x] `main_shell.dart`: navbar flotante **abajo, centrada, tipo
      pastilla**, con `BackdropFilter` (blur 24), `surfaceContainerHigh`
      translúcido, `BorderRadius.circular(32)`. Indicador activo con
      ancho elástico e íconos outlined → rounded con escala 1.15×.
      Respuesta háptica y compresión 0.92× al presionar.
- [x] Botón de ajustes como **cápsula flotante arriba a la derecha**,
      con `tertiaryContainer` y badge pulsante opcional
      (`kShowSettingsBadge = false`).
- [x] `PageView` con padding inferior para no quedar tapado por la
      navbar.

#### Ajustes (`settings_screen.dart`)
- [x] `CustomScrollView` + `SliverAppBar.large` "Ajustes" +
      `TonalBackButton`.
- [x] Bento cards con `SectionLabel` uppercase.
- [x] Card "Tema y color" con `ThemeBadges` (chips + punto de color).
- [x] Hero card "Datos de la relación" (`RelationshipSummaryCard`
      variante `hero`).
- [x] Footer "Ailoviu / versión dinámica / Acerca de"
      (`AboutFooterCard`).
- [x] Transición orgánica a subpantallas con `PageRouteBuilder`
      (fade + scale 0.96→1.0, `easeOutCubic`).

#### Tema y color (`appearance_screen.dart`)
- [x] `SliverAppBar.large` con `TonalBackButton`.
- [x] `BouncingScrollPhysics` + `CustomScrollView`.
- [x] Bento cards con `TonalMicroHeader`.
- [x] Modo brillo con 3 `BrightnessCard` (Sistema/Claro/Oscuro)
      independientes, selección `primaryContainer` + ícono 1.15×.
- [x] Tarjeta AMOLED con `AnimatedOpacity` (1.0 → 0.5 si no aplica) +
      badge "Solo en modo oscuro".
- [x] `SeedColorChip` con **morphing real** entre `M3EShape.circle` y
      `M3EShape.cookie4Sided`, glow del propio color, escala 1.10× al
      seleccionar, 0.85× al presionar.

#### Relación (`relationship_screen.dart`)
- [x] `SliverAppBar.large` con `TonalBackButton`.
- [x] `RelationshipPreview` rediseñado como hero card con gradiente
      tonal, avatares, `AnniversaryBadge` ("2 años y 4 meses juntos").
      Se anima con fade + scale al cambiar datos.
- [x] Selector de tipo con `ShapeSelectorCard`: mosaico de formas M3E
      (`circle`, `triangle`, `square`, `cookie6Sided`, `diamond`,
      `arch`). Selección con escala 1.08×, outlined → filled.
- [x] Nombres con `TextField` relleno (radio 20), avatar A/B/C en
      `secondaryContainer`, focus con iluminación primary.
- [x] `AnniversaryCard` con estado vacío y configurado, fecha extendida
      ("14 de febrero, 2022") + chip "2 años".
- [x] `DangerActionCard` + `ConfirmDeleteDialog` M3E.
- [x] `BouncingScrollPhysics`.
- [x] Labels corregidos: "Hétero" (con tilde), "Poliamor" (sin "Trio").

#### Acerca de (`about_screen.dart`)
- [x] `SliverAppBar.large` "Acerca de" + `TonalBackButton`.
- [x] `AboutHeroCard` con corazón `M3EShape.heart` con heartbeat
      animado (1.0 → 1.08×), "Ailoviu" en `displayMedium` w900, chip
      de versión **dinámico** vía `package_info_plus`.
- [x] Easter egg háptico: doble `mediumImpact` al tocar el corazón.
- [x] `_PurposeCard` con mensaje narrativo y firma.
- [x] `_LicensesCard` con `showLicensePage` custom.
- [x] `_ActionChipsRow` (Calificar / Sitio web / Compartir) con
      `SnackBar "próximamente"`.
- [x] `_CopyrightFooter` con año automático.

#### Providers
- [x] `relationship_providers.dart`: enum con labels correctos
      ("Hétero", "Poliamor"). Sin "Trieja" ni "Trio".
- [x] `app_info_providers.dart`: `appVersionProvider` y
      `appBuildNumberProvider` vía `package_info_plus`.

#### Paquetes locales
- [x] `packages/m3e_shapes/` integrado: 35 formas M3E con morphing
      real vía `M3EMorphClip`.
- [x] `packages/m3e_progress/` presente, aún sin usar en la app.
- [x] `pubspec.yaml` con `m3e_shapes: { path: packages/m3e_shapes }`
      y `package_info_plus: ^8.0.0`.

#### Workflow
- [x] `build.yml` con auto-versionado por `github.run_number`
      (`0.1.${run_number}+${run_number}`). Próxima build = 0.1.28.
- [x] Eliminados steps obsoletos de versionado hardcodeado.

#### Documentación
- [x] `ARQUITECTURA.md` reescrito centrado en reglas duras (14
      reglas numeradas), sin inventario de pantallas.
- [x] `ESTADO.md` actualizado (este archivo).
- [x] `PENDIENTES.md` actualizado con ítems nuevos.
- [x] `sesion-2026-10-27.md` con el resumen completo de la sesión.

## 🔜 Siguiente (Fase 2)

1. **`home_screen.dart` real**:
   - Hero card con `RelationshipSummaryCard(variant: compact)` o
     `RelationshipPreview`.
   - "Días juntos" con `AnniversaryBadge`.
   - Cards de acceso rápido a "Mensajes" y "Calendario" cuando esas
     pantallas existan.
2. **`calendar_screen.dart`** real (hoy placeholder).
3. **`connection_screen.dart`** real (mensajes, hoy placeholder).
4. **`play_screen.dart`** real (juegos, hoy placeholder).
5. **URLs reales** para "Calificar", "Sitio web" y "Compartir" en
   About (hoy `SnackBar "próximamente"`).

## 🐛 Bugs abiertos
- (ninguno)

---

## Instrucción explícita para la IA: archivos completos

Al proponer cambios de código, entregar **siempre el archivo completo**,
no fragmentos ni diffs por bloques. El usuario no edita archivos por
partes: copia y pega el archivo entero.

Aplica a:
- `pubspec.yaml`
- Cualquier `*.dart`
- Workflows `.github/workflows/*.yml`
- `AndroidManifest.xml`, `build.gradle.kts`, etc.
- Cualquier `*.md`

Si un archivo ya existía y hay que modificarlo, entregar la versión
completa con los cambios incorporados, no "cambia esta línea por esta".
Si el archivo es muy largo para un solo mensaje, dividirlo en mensajes
numerados dejando claro cuál es el archivo final completo.

**Motivo:** el usuario trabaja sin IDE. Editar por bloques provoca
errores de imports faltantes, líneas duplicadas y archivos a medio
actualizar.

## Instrucción explícita para la IA: entorno del desarrollador

El usuario trabaja **100% desde el celular**, sin PC ni terminal.
No puede ejecutar `flutter pub get`, `flutter run` ni `flutter build`
en local. Todo el ciclo de compilación ocurre en GitHub Actions
(`.github/workflows/build.yml`).

Consecuencias para la IA:
- Nunca proponer comandos de terminal como paso obligatorio.
- Los cambios se validan lanzando el workflow `Build APK` desde la
  web/app de GitHub.
- Si un build falla, el usuario pegará el log del step en rojo;
  diagnosticar a partir de ese log.
- Todo cambio debe entregarse como archivo completo (ver regla
  anterior) porque cada iteración cuesta ~5-10 min de CI.
- Al reorganizar archivos, los imports rotos (especialmente los que no
  empiezan con `./` o `../`) hay que corregirlos a mano; el script
  `reorganize.py` tiene bugs conocidos (ver `PENDIENTES.md` ítem 8).

## Instrucción explícita para la IA: idioma y estilo

- **Sentence case** en toda la UI.
- **Español mexicano o neutro**. Evitar castellanismos.
- **"Relación"** en UI, nunca "pareja".
- **"Hétero"** con tilde.
- **"Poliamor"** en UI, nunca "Trio" ni "Trieja".
- No usar la palabra "backlog" en conversación; decir "pendientes" o
  "lo anotado". El archivo se llama `PENDIENTES.md`.

## Instrucción explícita para la IA: pantallas sin scroll

La regla "sin scroll" aplica **solo a pestañas del shell** (Inicio,
Calendario, Mensajes, Juegos). Las **rutas push** (Ajustes, Tema y
color, Datos de la relación, Acerca de) **pueden scrollear libremente**
con `CustomScrollView` + `SliverList`. No proponer "reducir para que
quepa" en pantallas push.

## Instrucción explícita para la IA: regla de los MD

Los archivos `.md` (`ARQUITECTURA.md`, `ESTADO.md`, `PENDIENTES.md`,
`sesion-*.md`) **no se tocan durante la sesión de trabajo**. Se
actualizan en un **commit único al cierre de la sesión**.

**Motivo:** evitar commits intermedios de docs que interrumpen el flujo
de builds y dificultan el diff.