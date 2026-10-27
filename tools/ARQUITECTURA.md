# ARQUITECTURA

## Stack Técnico
- **Framework:** Flutter 3.47.7 (Dart)
- **Diseño:** Material 3 (M3 Expressive a futuro)
- **Package ID:** com.iruletas.ailoviu
- **Estado global:** `flutter_riverpod` 2.x
- **Persistencia local:** `shared_preferences` 2.x (settings)
- **CI/CD:** GitHub Actions (ubuntu-22.04, Java 17)
- **Firma:** Keystore `.jks` inyectado por Base64 en los Secrets de GitHub.
- **Estrategia de Gradle:** Inyección quirúrgica por Python en `build.gradle.kts` para evitar conflictos con AGP 9.0.

## Convenciones
- Nombres de archivos en `snake_case`.
- Un feature = una carpeta en `lib/features/`.
- Lógica separada de la UI (Riverpod).
- Ignorar carpetas nativas generadas por Flutter (solo mantener Android configurado).
- Claves de `shared_preferences` con prefijo por dominio: `settings.*`, `diary.*`, `period.*`, etc.

## Regla: pantallas principales delgadas

Ninguna `*_screen.dart` de nivel superior (las que cuelgan de `main_shell`
o del hub de Ajustes) debe contener lógica ni UI compleja. Su única
responsabilidad es:

1. Leer el estado necesario (`ref.watch`).
2. Componer `ListTile`s / botones de navegación, o
3. Delegar el cuerpo real a widgets/screens secundarias.

**Regla práctica:** si una screen principal supera ~150 líneas, es señal
de que su contenido debe extraerse a:
- `widgets/` dentro de su propia feature (para trozos de UI reutilizables), o
- una screen secundaria propia (para flujos completos).

**Ejemplo aplicado:** `settings_screen.dart` es solo un hub de `ListTile`s
que navegan a `appearance/`, `couple/` y `about/`. Nunca crece; crece
el número de destinos.

**Motivo:** en un proyecto anterior, `settings_screen.dart` llegó a ~2000
líneas por mezclar navegación, formularios y lógica. Esta regla existe
para que no vuelva a pasar.

## Regla: sin scroll en pantallas principales

**Intención de diseño:** toda pantalla principal debe caber completa en
una pantalla de móvil estándar (~360×800 dp) **sin necesidad de hacer
scroll vertical**.

Consecuencias prácticas:
- Las pantallas principales usan `Column` + `Spacer`/`Expanded`, no
  `ListView`, salvo que el contenido lo justifique.
- Si el contenido no cabe, hay tres opciones, en este orden:
  1. **Reducir**: menos texto, iconos más compactos, menos padding.
  2. **Agrupar**: consolidar controles en un solo widget (ej. `SegmentedButton`
     en lugar de 3 `RadioListTile`).
  3. **Mover a pantalla secundaria**: si nada de lo anterior funciona,
     el contenido vive en su propia screen y la principal solo muestra
     un `ListTile` de acceso.
- Las pantallas secundarias (a las que se navega con `Navigator.push`)
  **sí pueden** tener scroll si el contenido lo exige.

**Motivo:** la app se usa en el móvil, muchas veces con una mano. El
scroll vertical en pantallas principales rompe la sensación de "todo
a la vista" que queremos.

## Regla: hub de ajustes

`settings_screen.dart` es un hub de navegación, no un formulario.
Contiene solo `ListTile`s que abren screens secundarias o abren diálogos
pequeños (≤3 inputs). Los toggles simples (`SwitchListTile`) pueden
quedarse en el hub; todo lo demás va a su propia screen.

Cada `ListTile` del hub muestra en `subtitle` el valor actual del setting,
para que el usuario vea su configuración sin entrar.