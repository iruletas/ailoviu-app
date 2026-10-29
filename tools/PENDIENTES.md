# PENDIENTES

Ítems decididos pero no implementados. No son deuda: son trabajo
planificado. Cuando se aborda uno, se mueve a `ESTADO.md` como "en
curso" y se borra de aquí. Si se descarta, se borra.

---

## 1. Sync entre dos (o más) celulares + eliminación recíproca
**Qué:** datos de relación compartidos entre dispositivos. Si uno
elimina, el otro lo ve eliminado. Si termina la relación, no quedan
datos sensibles en el otro.

**Por qué no hoy:** no hay backend. Es arquitectura de seguridad, no
una pantalla.

**Dónde vivirá:** `lib/services/sync_service.dart`,
`lib/services/auth_service.dart` (extendido), migración de
`providers/relationship_providers.dart` a fuente remota.

**Preguntas abiertas:**
- ¿Identidad por código de invitación (sin email) o por email?
- ¿Eliminación inmediata o al abrir la app? ¿Offline?
- ¿Claves por relación que se destruyen al terminar?

---

## 2. Login / cuenta de usuario
**Qué:** autenticación para identificar a cada miembro.

**Por qué no hoy:** sin backend, un campo de email no hace nada.

**Qué desbloquea:** ítem 1 (sync).

**Dónde vivirá:** `lib/services/auth_service.dart` (extendido) +
`lib/screens/account_screen.dart`.

---

## 3. Fotos de perfil reales
**Qué:** avatar con foto de la galería o cámara.

**Por qué no hoy:** requiere `image_picker` + permisos. El avatar con
inicial + seed cubre la necesidad visual al 100% mientras tanto.

**Dónde vivirá:** `lib/services/gallery_service.dart` (compartido con
fotos de recuerdos).

**Nota:** Android 13+ Photo Picker no requiere permiso. No añadir
`READ_MEDIA_IMAGES` al Manifest hasta que se implemente.

---

## 4. Permisos de almacenamiento
**Qué:** permisos para leer/escribir imágenes.

**Por qué no hoy:** no se usan. Poner permisos sin uso provoca rechazo
en Google Play.

**Regla:** los permisos se añaden el día que se usan.

---

## 5. Más de 3 miembros en la relación
**Qué:** soportar 4+ miembros.

**Por qué no hoy:** la UI cubre 2 y 3. El modelo ya es `List<String>`,
sin deuda de datos; solo falta UI.

**Dónde vivirá:** `screens/relationship_screen.dart` +
`widgets/partner_list_editor.dart` (reutilizable).

---

## 6. URLs reales para Calificar / Sitio web / Compartir
**Qué:** los 3 action chips de `about_screen.dart` muestran
`SnackBar "próximamente"`.

**Por qué no hoy:** no hay URL de Play Store, ni landing, ni decisión
de copy.

**Dónde vivirá:** `about_screen.dart` + `pubspec.yaml`
(`url_launcher`, `share_plus`, `in_app_review`).

---

## 7. `m3e_progress` integrado a la app
**Qué:** el paquete local `packages/m3e_progress/` tiene 10 estilos de
barra lineal, 8 de arco, slider con onda, y `MorphingPlayPauseButton`.
Hoy está en `packages/` pero no se usa.

**Por qué no hoy:** no hay pantalla que use progreso todavía.

**Qué desbloquea:** `play_screen.dart` (juegos) o reproductor de
recuerdos con `MorphingPlayPauseButton`.

---

## 8. Workflow de reorganización atómica (mejoras)
**Qué:** `reorganize.py` tiene 3 bugs conocidos:
1. Comillas duplicadas en imports.
2. No colapsa subcarpetas.
3. No reescribe imports sin `./` ni `../`.

**Por qué no hoy:** cumplió su función. Arreglarlo es una sesión
propia.

---

## 9. Iconos de avatar
**Qué:** reemplazar la inicial estilizada por iconos seleccionables.

**Por qué no hoy:** para no elegir iconos que luego se necesiten en
otra parte.

**Nota:** con `m3e_shapes` integrado, este ítem se puede hacer con
`ShapeSelectorCard` + `M3EShape` reutilizados.

**Dónde vivirá:** `relationship_screen.dart` + `widgets/relationship_preview.dart`.

---

## 10. Home real con datos
**Qué:** `home_screen.dart` es un placeholder. Debe componerse de
hero de relación + días juntos + estados + una acción única.

**Por qué no hoy:** Bloque C.

**Dónde vivirá:** `lib/screens/home_screen.dart`.

---

## 11. Renombrar pestaña "Mensajes" → "Nosotros"
**Qué:** la pestaña 3 de la navbar dice "Mensajes". Cuando sea el hub
de Diario, Cartas, Estados, Recuerdos, Listas, Vales, Metas, Sueños
(8+ features), "Mensajes" no describe la pestaña.

**Por qué no hoy:** es un cambio de identidad de la app. Se decide
antes de meter features ahí.

**Dónde vivirá:** `lib/screens/main_shell.dart` (label + íconos).

---

## 12. `FeatureGate` wrapper para funciones privadas
**Qué:** hoy existe `AuthGate` a nivel app (`widgets/auth_gate.dart`).
Cuando una feature privada (Diario, Cartas, Recuerdos, Galería)
aterrice, necesita un wrapper `FeatureGate(featureId: 'diary', child: ...)`
que:
- En entrada: consulte `featureLocksProvider[featureId].requiresAuth`;
  si es `true` y `!session.isFeatureUnlocked(featureId)`, pida auth
  con `AuthService.authenticateWithSystem()` (o PIN fallback).
- En salida: llame `authSessionProvider.notifier.lockFeature(featureId)`.
- Sin timeout (por diseño).

**Dónde vivirá:** `lib/widgets/feature_gate.dart`.

**Cuándo:** cuando llegue la primera feature privada (probablemente
Diario, bloque D).

---

## 13. Privacy blur en multitarea (deferred)
**Qué:** overlay con `BackdropFilter` cuando la app va a background,
para ocultar datos sensibles en el app switcher.

**Por qué no hoy:** `AppLifecycleState.inactive` se dispara al abrir
la barra de notificaciones (blur fantasma), y `FLAG_SECURE` nativo
rompe capturas legítimas. Requiere más diseño.

**Dónde vivirá:** `widgets/auth_gate.dart` (superponer capa cuando
`lifecycle != resumed`).

---

## 14. Botón "Bloquear ahora" (manual)
**Qué:** acción manual para bloquear la app, útil cuando el timeout
está en "Nunca" pero el usuario quiere bloquear rápido.

**Dónde vivirá:** probablemente en `settings_screen.dart` o en
long-press de la pill de ajustes en `main_shell.dart`.

---

## 15. Push real (FCM) y Cloud Functions
**Qué:** El `push_service.dart` solo registra el token, pero el envío
del push cuando llega un mensaje requiere una Cloud Function o un
servidor. Como usamos el servicio en primer plano
(`flutter_foreground_task`), las notificaciones ya llegan con la app
cerrada sin necesidad de FCM. Si queremos notificaciones cuando el
servicio esté apagado (o en iOS), necesitaremos desplegar la Cloud
Function.

**Por qué no hoy:** el servicio en primer plano cubre el caso de uso
y evita configurar Cloud Functions (que requieren plan Blaze de
Firebase).

**Dónde vivirá:** `functions/index.js` + instrucciones en el
onboarding.

---

## Notas (no son ítems, son avisos para no tropezar)

### Warning de KGP en `package_info_plus`
Flutter 3.47.7 emite "plugins that apply KGP" para
`package_info_plus`. **No bloquea build.** Se resolverá solo cuando
`package_info_plus` publique versión compatible con Built-in Kotlin
(actualizar dependencia, un build). Revisar también `local_auth` en
ese momento.

### Caché de Gradle
Mover archivos en `lib/` invalida el caché de Gradle (el hash del
árbol cambia) y la siguiente build descarga NDK + CMake + Build Tools
(~2 GB). **Agrupa reorganizaciones en un solo commit.**

### NDK transitorio
El build puede fallar esporádicamente por descarga corrupta del NDK
r28c (`Archive is not a ZIP archive`). Es transitorio del runner.
**Solución: re-lanzar el workflow.**

### Versionado
Desde 2026-10-28, se volvió al auto-versionado `0.1.{run_number}`
porque el flujo manual es más molesto para el desarrollador.
`pubspec.yaml` en el repo dice `0.1.0+1`, pero el workflow lo
sobrescribe antes de compilar.

### Imports de tipos devueltos por providers
Cuando uses `ref.read(provider.future)` o `ref.watch(provider)` y
vayas a llamar métodos sobre el resultado, **importa el archivo del
tipo**. Sin el import, Dart cae a `Object?` y los métodos no
resuelven. (Aprendido con `AuthSession` en `auth_gate.dart` y con
`AuthService` en `security_screen.dart`).

### Firma de APK en Android
Si Android dice "paquete no válido", es casi seguro que la app
instalada tiene una firma distinta (de debug, o de un keystore viejo).
Solución: desinstalar la versión vieja y volver a instalar. Las
actualizaciones futuras (con el mismo keystore) ya no pedirán
desinstalar.