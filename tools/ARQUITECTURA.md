# ARQUITECTURA

## Stack Técnico
- **Framework:** Flutter 3.47.7 (Dart)
- **Diseño:** Material 3 (M3 Expressive a futuro)
- **Package ID:** com.iruletas.ailoviu
- **CI/CD:** GitHub Actions (ubuntu-22.04, Java 17)
- **Firma:** Keystore `.jks` inyectado por Base64 en los Secrets de GitHub.
- **Estrategia de Gradle:** Inyección quirúrgica por Python en `build.gradle.kts` para evitar conflictos con AGP 9.0.

## Convenciones
- Nombres de archivos en `snake_case`.
- Un feature = una carpeta en `lib/features/`.
- Lógica separada de la UI (Riverpod a futuro).
- Ignorar carpetas nativas generadas por Flutter (solo mantener Android configurado).