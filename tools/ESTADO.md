# ESTADO DEL PROYECTO

_Última actualización: 2026-10-27_

## Fase actual
Fase 1 – Shell + Settings (en curso)

## ✅ Hecho

### Fase 0 – Configuración base (Completada)
- [x] Repo público `ailoviu-app` creado.
- [x] Estructura limpia de Flutter (`lib/main.dart`, `pubspec.yaml`).
- [x] `AndroidManifest.xml` y `MainActivity.kt` configurados con `com.iruletas.ailoviu`.
- [x] Workflow `build.yml` con Artifacts, limpieza automática y caché de Gradle.
- [x] Keystore generado, guardado en Secrets y configurado para firmar la APK.
- [x] Versión forzada a `0.1.0` con auto-incremento del `versionCode`.
- [x] APK firmada descargada e instalada en el teléfono.

### Fase 1 – Shell + Settings (en curso)
- [x] `lib/main.dart` con `ProviderScope`.
- [x] `lib/app.dart` con `MaterialApp`, `theme`/`darkTheme`/`themeMode` desde Riverpod.
- [x] `lib/main_shell.dart`: navbar flotante arriba con `PageView` y 4 destinos
      (Inicio, Calendario, Mensajes, Juegos) + FAB de engranaje a la derecha
      para Ajustes. Sin `AppBar`.
- [x] Placeholders: `home_screen`, `calendar_screen`, `messages_screen`,
      `play_screen`, `settings_screen`.
- [x] `core/theme/app_theme.dart`: `buildTheme({brightness, seed, amoled})`.
- [x] `core/theme/seed_palette.dart`: 6 colores semilla curados.
- [x] `core/settings/settings_providers.dart`: `AppSettings` + `SettingsNotifier`
      con persistencia en `shared_preferences` (themeMode, seedColor, amoled,
      startDate).
- [x] `features/settings/settings_screen.dart`: hub con `ListTile`s y `subtitle`
      dinámico.
- [x] `features/settings/appearance/appearance_screen.dart`: `SegmentedButton`
      (Sistema/Claro/Oscuro con icono `phone_android_outlined` para Sistema),
      `SwitchListTile` AMOLED (deshabilitado si no es oscuro), y `Wrap` de
      chips de seed color.
- [x] `features/settings/couple/couple_screen.dart`: selector de fecha de
      inicio con `showDatePicker` y botón de borrar.
- [x] `features/settings/about/about_screen.dart`: versión + licencias.

## 🔜 Siguiente (resto de Fase 1)
1. `home_screen.dart`: tarjeta "Días juntos" leyendo `settings.startDate`
   del provider. Sin scroll (regla de diseño).
2. Nombres de pareja en `couple_screen.dart` (2 `TextField`).
3. Ampliar destinos del navbar solo si aparecen features reales
   (Calendario/Mensajes son placeholders por ahora).

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

**Motivo:** el usuario trabaja sin IDE. Editar por bloques provoca errores
de imports faltantes, líneas duplicadas y archivos a medio actualizar.

## Instrucción explícita para la IA: entorno del desarrollador

El usuario trabaja **100% desde el móvil**, sin PC ni terminal.
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

## Instrucción explícita para la IA: pantallas sin scroll

Toda propuesta de UI debe respetar la regla "sin scroll en pantallas
principales" de `ARQUITECTURA.md`. Si el contenido no cabe, proponer
reducción, agrupación o extracción a pantalla secundaria, en ese orden.