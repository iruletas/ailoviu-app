# Vinculación, sync y recuperación — cómo probar

Este documento explica cómo probar el flujo completo con dos
dispositivos Android. Asume que ya compilaste la APK con los
Bloques 1–5.

## Prerrequisitos

- Dos dispositivos Android con la app instalada.
- Un proyecto de Firebase (tuyo, uno solo) con Realtime Database
  habilitada y las reglas del archivo `firebase-rules.json`
  aplicadas.
- El `google-services.json` de ese proyecto a mano (en un archivo de
  texto, en el portapapeles, o en un correo a ti mismo).

## Paso 0 — Limpieza inicial

En **ambos** dispositivos, si tenías la app instalada de antes:

- Desinstalar la app completamente (no solo actualizar). Esto borra
  el Keystore viejo con formato antiguo.

## Paso 1 — Configurar Firebase en el host (Dispositivo A)

1. Ajustes → Conexiones → Firebase → pegar `google-services.json`.
2. Guardar. La app dice "Configurado".

## Paso 2 — Crear el grupo en el host (Dispositivo A)

1. Ajustes → Conexiones → Vinculación → Crear grupo.
2. Pide: tu nombre (displayName), pregunta de recuperación (ej.
   "¿Cómo se llamaba nuestra primera mascota?"), respuesta.
3. La app genera el QR con las credenciales cifradas. **Muéstralo
   en pantalla.**

## Paso 3 — Unirse (Dispositivo B)

1. Ajustes → Conexiones → Vinculación → Unirme a un grupo.
2. Escanear el QR del Dispositivo A.
3. Pide tu nombre (displayName). Lo escribes.
4. La app descifra las credenciales, las guarda en Keystore, y
   publica la solicitud en `invites/{token}/requests/` de Firebase.
5. Verás en pantalla: "Esperando aprobación del grupo".

## Paso 4 — Aprobar (Dispositivo A)

1. El host recibe una notificación: "👤 Fulano quiere unirse".
2. Ajustes → Conexiones → Vinculación → Pendientes.
3. Aparece la tarjeta de Fulano. Toca "Aprobar".
4. El host (único miembro aprobado) completa la unanimidad.
5. El guest recibe `memberAccept` y ve "Ya eres parte del grupo".

**Si hay 3+ miembros:** cada uno debe aprobar en su propio
dispositivo. Hasta que el último apruebe, el guest no entra.

## Paso 5 — Probar el buzz, el status y la ubicación

En Dispositivo A:

1. Hogar → tocar el botón de buzz (esquina superior izquierda).
2. En Dispositivo B: debe vibrar (heavy) y aparecer notificación
   "⚡ Zumbido".
3. Cambiar status en A: B lo ve en el mapa.
4. Compartir ubicación en A: B lo ve en el mapa.

## Paso 6 — Recuperación (perder el celular / cambiar de teléfono)

### Escenario A — Cambiaste de teléfono (todavía tienes el viejo)

1. En el Dispositivo viejo: Ajustes → Conexiones → Vinculación →
   Compartir recuperación. Muestra un QR.
2. En el Dispositivo nuevo: Ajustes → Conexiones → Vinculación →
   Recuperar cuenta. Escanea el QR del viejo.
3. Pide: nombre (displayName), respuesta a la pregunta de
   recuperación, y PIN viejo (opcional).
4. La solicitud se publica en `invites/{token}/requests/`.
5. En **todos** los demás dispositivos del grupo, aparece una
   notificación: "🔄 Fulano quiere recuperar su cuenta".
6. Cada uno abre la tarjeta. El host **primero** verifica A (escribe
   la respuesta en el diálogo) y opcionalmente B (si el guest mandó
   su PIN viejo). Si pasa A o B, el host vota sí.
7. Cuando todos votan sí, el host promueve: el deviceId viejo se
   reemplaza por el nuevo. El resto de miembros ve el cambio.

### Escenario B — Perdiste el celular (no tienes el viejo)

1. El nuevo dispositivo **no puede escanear el QR de recuperación**
   porque ese QR está en el viejo. **Falta un paso**: el otro
   miembro del grupo (o el host) genera el QR de recuperación
   **desde su dispositivo**, apuntando al deviceId viejo. Ese QR se
   lo pasa al dueño del nuevo dispositivo por fuera de la app
   (WhatsApp, email, etc.).
2. El dueño del nuevo dispositivo escanea el QR, responde A, y el
   flujo sigue igual que el Escenario A.
3. **Si nadie más está disponible** (solo hay 2 miembros y uno
   perdió el celular), no hay recuperación posible. Es el costo de
   no tener email.

## Paso 7 — Expulsar a alguien

1. En cualquier dispositivo aprobado: Ajustes → Conexiones →
   Vinculación → tocar el miembro → Expulsar.
2. Se pide confirmación.
3. El expulsado recibe `memberLeave`. El resto borra sus secrets.
   El historial sigue accesible para los que quedan.

## Limitaciones conocidas (PENDIENTES)

- **Todos pierden el celular:** sin recuperación. Se documenta en
  `tools/PENDIENTES.md` ítem 19.
- **Cloud Functions:** no hay. Las notificaciones dependen del
  servicio en primer plano. Si el servicio está apagado, no hay
  notificación hasta que la app se abra.
- **iOS:** no soportado por ahora. El proyecto es Android-only.

## Troubleshooting

### "El QR expiró"
Los QR de join caducan a los 10 min. Los de recuperación a 30 min.
Genera uno nuevo.

### "Este dispositivo ya pertenece a otro grupo"
Tu dispositivo tiene un `groupId` guardado y no es el que escaneaste.
Si es un grupo huérfano (solo tú), la app lo limpia al crear uno
nuevo. Si tiene más miembros, tienes que expulsarte del grupo viejo
primero.

### "Ni la respuesta ni el PIN coinciden"
El host escribió mal la respuesta, o el guest no recordaba el PIN
viejo. El host tiene que escribir la respuesta exacta (la
normalización ignora mayúsculas y acentos, pero no errores de
escritura). El PIN solo se puede intentar si el guest lo recuerda.

### "Sin conexión"
Revisa:
- Que el `google-services.json` esté pegado correctamente en ambos.
- Que las reglas de Firebase estén publicadas.
- Que Realtime Database esté habilitada en el proyecto.
- Que `auth != null` se cumpla (la app llama `signInAnonymously()`
  automáticamente; si falla, revisa que Anonymous Auth esté
  habilitado en Firebase Console → Authentication → Sign-in method).

### Un miembro no ve la notificación de join
El miembro debe tener la app abierta o el servicio en primer plano
corriendo. `BackgroundSyncService.bootstrap()` arranca el servicio
si hay pareja + config. Si está apagado, no hay notificación hasta
que abra la app.