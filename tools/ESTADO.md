# ESTADO DEL PROYECTO

_Última actualización: 2026-10-27_

## Fase actual
Fase 1 – Shell + Ajustes + Relación (casi completa)

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
- [x] Versión forzada a `0.1.0` con auto-incremento del `versionCode`.
- [x] APK firmada descargada e instalada en el celular.

### Fase 1 — Shell + Ajustes + Relación
- [x] `lib/main.dart` con `ProviderScope`.
- [x] `lib/app.dart` con `MaterialApp`, `theme`/`darkTheme`/`themeMode`
      desde Riverpod.
- [x] `lib/screens/main_shell.dart`: navbar flotante arriba con
      `PageView` y 4 destinos (Inicio, Calendario, Mensajes, Juegos) +
      FAB de engranaje a la derecha para Ajustes. Sin `AppBar`.
- [x] Placeholders: `home_screen`, `calendar_screen`,
      `connection_screen`, `play_screen`.
- [x] `core/app_theme.dart`: `buildTheme({brightness, seed, amoled})`.
- [x] `core/seed_palette.dart`: 6 colores semilla curados.
- [x] `providers/settings_providers.dart`: `AppSettings` +
      `SettingsNotifier` con persistencia de `themeMode`, `seedColor`,
      `amoled`.
- [x] `providers/relationship_providers.dart`: `AppRelationship`,
      `RelationshipType` (hetero, lesbiana, gay, poliamor/trio,
      abierta, otro), `RelationshipNotifier` con persistencia de
      `partnerNames`, `type`, `startDate`.
- [x] `widgets/relationship_preview.dart`: header reutilizable con
      avatares de inicial + seed, nombres, tipo y días juntos.
- [x] `screens/settings_screen.dart`: hub con `ListTile`s y `subtitle`
      dinámico.
- [x] `screens/appearance_screen.dart`: `SegmentedButton`
      (Sistema/Claro/Oscuro con `phone_android_outlined` para Sistema),
      `SwitchListTile` AMOLED (deshabilitado si no es oscuro), `Wrap`
      de chips de seed color.
- [x] `screens/relationship_screen.dart`: tipo de relación con formas
      geométricas, nombres autoguardados, fecha de inicio, vista previa
      en vivo, eliminar con confirmación.
- [x] `screens/about_screen.dart`: versión + licencias. **Fea**
      (cosmética pendiente).
- [x] `pubspec.yaml` con `shared_preferences ^2.3.0` y
      `flutter_riverpod ^2.5.1`.
- [x] Reorganización de `lib/` a estructura plana por capas
      (`core/`, `providers/`, `screens/`, `widgets/`).
- [x] Workflow `reorganize.yml` + `tools/reorganize.py` probados
      (14 archivos movidos, 4 imports reescritos, 11 carpetas vacías
      borradas).
- [x] APK compilada con todos los cambios e instalada.

## 🔜 Siguiente (resto de Fase 1)
1. `home_screen.dart`: tarjeta "Días juntos" leyendo
   `relationshipProvider` (startDate). Reutilizar `RelationshipPreview`.
2. Nombres de pareja: ya hechos en `relationship_screen.dart`.
3. Revisar cosmética de `about_screen.dart`.
4. Añadir destinos al navbar solo cuando aparezcan features reales.

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
  `reorganize.py` tiene bugs conocidos (ver `PENDIENTES.md` ítem 9).

## Instrucción explícita para la IA: idioma y estilo

- **Sentence case** en toda la UI.
- **Español mexicano o neutro**. Evitar castellanismos.
- **"Relación"** en UI, nunca "pareja".
- No usar la palabra "backlog" en conversación; decir "pendientes" o
  "lo anotado". El archivo se llama `PENDIENTES.md`.

## Instrucción explícita para la IA: pantallas sin scroll

Toda propuesta de UI debe respetar la regla "scroll en pantallas
principales" de `ARQUITECTURA.md`. Si el contenido no cabe, proponer
reducción, agrupación o scroll justificado, en ese orden.