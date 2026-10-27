# PENDIENTES

Ítems decididos pero no implementados. No son deuda: son trabajo
planificado. Cuando se aborde uno, se mueve a `ESTADO.md` como "en
curso" y se borra de aquí. Si se descarta, se borra.

---

## 1. Sync entre dos (o más) celulares + eliminación recíproca
**Qué:** datos de relación compartidos entre dispositivos. Si uno
elimina, el otro lo ve eliminado. Si termina la relación, no quedan
datos sensibles en el otro.

**Por qué no hoy:** no hay backend. Es arquitectura de seguridad, no
una pantalla.

**Dónde vivirá:** `core/sync/`, `core/auth/`, migración de
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

**Dónde vivirá:** `core/auth/` + `screens/account_screen.dart`.

---

## 3. Fotos de perfil reales
**Qué:** avatar con foto de la galería o cámara.

**Por qué no hoy:** requiere `image_picker` + permisos. El avatar con
inicial + seed cubre la necesidad visual al 100% mientras tanto.

**Dónde vivirá:** `core/gallery/` (compartido con fotos de recuerdos).

**Nota:** en Android 13+ el Photo Picker **no requiere permiso**. No
añadir `READ_MEDIA_IMAGES` al Manifest hasta que se implemente.

---

## 4. Permisos de almacenamiento en `AndroidManifest.xml`
**Qué:** permisos para leer/escribir imágenes.

**Por qué no hoy:** no se usan. Poner permisos sin uso provoca rechazo
en Google Play.

**Regla:** los permisos se añaden el día que se usan, no antes.

---

## 5. Más de 3 miembros en la relación
**Qué:** soportar 4+ miembros.

**Por qué no hoy:** la UI cubre 2 y 3 (el tercero se desbloquea con
`polyamorous`). El modelo ya es `List<String> partnerNames`, así que
no hay deuda de datos; solo falta UI.

**Dónde vivirá:** `screens/relationship_screen.dart` (UI) y
posiblemente un `PartnerListEditor` reutilizable en `widgets/`.

---

## 6. Página de Calificar / Sitio web / Compartir (URLs reales)
**Qué:** las 3 action chips de `about_screen.dart` muestran
`SnackBar "próximamente"`. Necesitan handlers reales:
- **Calificar**: abrir Play Store de Ailoviu. Requiere `url_launcher`
  o `in_app_review`.
- **Sitio web**: abrir landing / web app. Requiere URL real.
- **Compartir**: `share_plus` para enviar la app.

**Por qué no hoy:** no hay URL de Play Store, ni landing, ni decisión
de copy para compartir.

**Dónde vivirá:** `about_screen.dart` (handlers) + `pubspec.yaml`
(`url_launcher`, `share_plus`, `in_app_review`).

---

## 7. `m3e_progress` integrado a la app
**Qué:** el paquete local `packages/m3e_progress/` tiene 10 estilos de
barra lineal, 8 de arco, slider con onda, y `MorphingPlayPauseButton`.
Hoy está en `packages/` pero no se usa.

**Por qué no hoy:** no hay pantalla que use progreso todavía. Los
juegos o el calendario podrían usarlo.

**Qué desbloquea:** `play_screen.dart` (juegos) o reproductor de
recuerdos con `MorphingPlayPauseButton`.

**Dónde vivirá:** importado desde `packages/m3e_progress/` con
`path:` en `pubspec.yaml`.

---

## 8. Workflow de reorganización atómica (mejoras)
**Qué:** `reorganize.py` tiene 3 bugs conocidos:
1. Comillas duplicadas en imports.
2. No colapsa subcarpetas.
3. No reescribe imports sin `./` ni `../`.

**Por qué no hoy:** cumplió su función. Arreglar el script es una
sesión propia.

**Dónde vivirá:** `tools/reorganize.py`.

---

## 9. Iconos de avatar
**Qué:** reemplazar la inicial estilizada por iconos seleccionables.

**Por qué no hoy:** para no elegir iconos que luego se necesiten en
otra parte (nav, settings, juegos, recuerdos).

**Nota:** ahora que `m3e_shapes` está integrado, este ítem se puede
hacer con `ShapeSelectorCard` + `M3EShape` reutilizados.

**Dónde vivirá:** `screens/relationship_screen.dart` (selector) y
`widgets/relationship_preview.dart` (render).

---

## 10. Home real con datos
**Qué:** `home_screen.dart` es un placeholder ("Inicio"). Debe
componerse de:
- `RelationshipSummaryCard(variant: compact)` o `RelationshipPreview`.
- `AnniversaryBadge` (días juntos).
- Cards de acceso rápido.

**Por qué no hoy:** Fase 1 priorizó Ajustes + Relación + Apariencia +
About. Home es Fase 2.

**Dónde vivirá:** `screens/home_screen.dart`.

---

## Notas (no son ítems, son avisos para no tropezar)

### Caché de Gradle
Mover archivos en `lib/` invalida el caché de Gradle (el hash del
árbol cambia) y la siguiente build descarga NDK + CMake + Build Tools
(~2 GB). **Agrupa reorganizaciones en un solo commit** para minimizar
el coste. Los commits que solo editan contenido no invalidan el caché.

### NDK transitorio
El build puede fallar esporádicamente por descarga corrupta del NDK
r28c (`Archive is not a ZIP archive`). Es transitorio del runner de
GitHub. **Solución: re-lanzar el workflow.**

### Auto-versionado
`github.run_number` cuenta ejecuciones del workflow, exitosas o
fallidas. La versión de la APK es `0.1.${run_number}`. Al probar en
el celular, la versión puede no coincidir con el `pubspec.yaml` del
repo (que siempre está en `1.0.0+1`). Es esperado.