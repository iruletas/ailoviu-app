# PENDIENTES

Ítems decididos pero no implementados. No son deuda: son trabajo
planificado. Cuando se aborde uno, se mueve a `ESTADO.md` como "en
curso" y se borra de aquí. Si se descarta, se borra.

---

## 1. Sync entre dos (o más) celulares + eliminación recíproca
**Qué:** datos de relación (nombres, tipo, fecha, avatares, y futuras
fotos/cartas) compartidos entre dos o más dispositivos. Si uno elimina,
el otro lo ve eliminado. Si termina la relación, no quedan datos
sensibles en el otro.

**Por qué no hoy:** no hay backend. Es arquitectura de seguridad, no
una pantalla. Requiere decisiones que no se toman en una sesión.

**Qué desbloquea:** decidir backend (Firebase/Supabase/propio), modelo
de identidad (código de invitación vs email), y diseño de eliminación
criptográfica por relación.

**Dónde vivirá:** `core/sync/`, `core/auth/`, migración de
`providers/relationship_providers.dart` a fuente remota.

**Preguntas abiertas:**
- ¿Identidad por código de invitación (sin email) o por email?
- ¿Eliminación inmediata o al abrir la app? ¿Offline?
- ¿Claves por relación que se destruyen al terminar? (eliminación
  criptográfica real, no `delete()`).

---

## 2. Login / cuenta de usuario
**Qué:** autenticación para identificar a cada miembro.

**Por qué no hoy:** sin backend, un campo de email no hace nada.

**Qué desbloquea:** ítem 1 (sync).

**Dónde vivirá:** `core/auth/` + `screens/account_screen.dart`.

---

## 3. Fotos de perfil reales
**Qué:** avatar con foto de la galería o cámara.

**Por qué no hoy:** requiere `image_picker` + permisos +
almacenamiento. El avatar con inicial + seed cubre la necesidad visual
al 100% mientras tanto.

**Qué desbloquea:** feature de Galería (comparte permisos y
almacenamiento).

**Dónde vivirá:** `core/gallery/` (compartido con fotos de recuerdos).

**Nota:** en Android 13+ el Photo Picker **no requiere permiso**. No
añadir `READ_MEDIA_IMAGES` al Manifest hasta que se implemente de
verdad.

---

## 4. Permisos de almacenamiento en `AndroidManifest.xml`
**Qué:** permisos para leer/escribir imágenes.

**Por qué no hoy:** no se usan. Poner permisos sin uso provoca rechazo
en Google Play y desconfianza en el usuario.

**Qué desbloquea:** ítem 3 (fotos) y Galería.

**Dónde vivirá:** `android/app/src/main/AndroidManifest.xml`.

**Regla:** los permisos se añaden el día que se usan, no antes.

---

## 5. Más de 3 miembros en la relación
**Qué:** soportar 4+ miembros (cuádruples, grupos grandes).

**Por qué no hoy:** la UI actual cubre 2 y 3 (el tercero se desbloquea
con `polyamorous`). El modelo ya es `List<String> partnerNames`, así
que no hay deuda de datos; solo falta UI.

**Qué desbloquea:** decidir si el tipo de relación deja de mapear
1→capacidad y pasa a ser "capacidad libre" (el usuario agrega/quita
miembros a voluntad, sin depender del enum).

**Dónde vivirá:** `screens/relationship_screen.dart` (UI) y
posiblemente un `PartnerListEditor` reutilizable en `widgets/`.

---

## 6. Package M3E (35 formas Material 3 Expressive)
**Qué:** importar las 35 formas M3E que el usuario ya tiene preparadas
en otro proyecto.

**Por qué no hoy:** mezclarlo con la pantalla de relación haría el
build indepurable si falla (no se sabría si falla por las formas, por
los providers o por los imports movidos). Es una sesión propia.

**Qué desbloquea:** revisar la API del package, elegir qué formas se
usan de verdad, integrarlas en el tema y en componentes concretos
(navbar, cards, botones), documentar la dependencia.

**Dónde vivirá:** `core/expressive_shapes.dart` (o similar) +
`pubspec.yaml`.

---

## 7. Iconos de avatar
**Qué:** reemplazar la inicial estilizada por iconos seleccionables
(animales, naturaleza, formas, etc.).

**Por qué no hoy:** para no elegir iconos que luego se necesiten en
otra parte de la app (navegación, settings, juegos, recuerdos).
Primero hay que tener el mapa completo de iconos usados, y al final
elegir los que queden libres.

**Qué desbloquea:** terminar la UI de navegación y features
principales (Home, Juegos, Recuerdos) para saber qué iconos están
ocupados.

**Dónde vivirá:** `screens/relationship_screen.dart` (selector) y
`widgets/relationship_preview.dart` (render).

**Nota:** la inicial estilizada es el fallback permanente cuando no
haya icono elegido o cuando lleguen fotos reales.

---

## 8. Workflow de reorganización atómica (mejoras)
**Qué:** el workflow `reorganize.yml` ya existe y funcionó, pero tiene
3 bugs conocidos:
1. **Comillas duplicadas**: el regex añade una `'` de más en algunos
   imports (`import '...'';`).
2. **No colapsa subcarpetas**: cuando el destino está en el mismo
   directorio que el origen, deja `about/about_screen.dart` en vez de
   `about_screen.dart`.
3. **No reescribe imports sin `./` ni `../`**: `import 'features/x.dart'`
   no se toca, y queda roto tras mover el archivo.

**Por qué no hoy:** el script cumplió su función (mover 14 archivos,
reescribir 4 imports, borrar 11 carpetas). Los 3 bugs se arreglan a
mano en 10 minutos (7 archivos rotos, ya corregidos). Arreglar el
script es una sesión propia.

**Qué desbloquea:** futuras reorganizaciones sin tener que corregir
archivos a mano.

**Dónde vivirá:** `tools/reorganize.py`.

---

## 9. Cosmética de `about_screen.dart`
**Qué:** la pantalla de "Acerca de" es funcional pero fea. Rediseñarla
con M3 (icono grande, versión, créditos, quizá logo).

**Por qué no hoy:** no bloquea nada funcional.

**Qué desbloquea:** nada, es puramente estético.

**Dónde vivirá:** `screens/about_screen.dart`.

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
GitHub. **Solución: re-lanzar el workflow.** Si se vuelve recurrente
(3+ fallos seguidos), añadir paso de limpieza de NDK o cambiar a
`ubuntu-24.04`.