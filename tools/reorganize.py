#!/usr/bin/env python3
"""
Reorganiza lib/ a la estructura acordada y actualiza imports relativos.
No toca .md, .yml, pubspec ni nada fuera de lib/.
Soporta DRY_RUN=true para solo mostrar cambios.
"""

import os
import re
import shutil
import sys
from pathlib import Path

REPO = Path('.').resolve()
LIB = REPO / 'lib'

DRY_RUN = os.environ.get('DRY_RUN', 'false').lower() == 'true'

# Mapa: ruta vieja (relativa a lib/) -> ruta nueva (relativa a lib/)
# Se incluyen ambas variantes de couple/relationship; el script filtra
# las que no existan y aborta si hay conflicto de destino.
MAPA = {
    'core/theme/app_theme.dart': 'core/app_theme.dart',
    'core/theme/seed_palette.dart': 'core/seed_palette.dart',
    'core/settings/settings_providers.dart': 'providers/settings_providers.dart',
    'core/relationship/relationship_providers.dart': 'providers/relationship_providers.dart',
    'core/relationship/relationship_preview.dart': 'widgets/relationship_preview.dart',
    'main_shell.dart': 'screens/main_shell.dart',
    'features/home/home_screen.dart': 'screens/home_screen.dart',
    'features/calendar/calendar_screen.dart': 'screens/calendar_screen.dart',
    'features/messages/messages_screen.dart': 'screens/connection_screen.dart',
    'features/play/play_screen.dart': 'screens/play_screen.dart',
    'features/settings/settings_screen.dart': 'screens/settings_screen.dart',
    'features/settings/appearance/appearance_screen.dart': 'screens/appearance_screen.dart',
    'features/settings/couple/couple_screen.dart': 'screens/relationship_screen.dart',
    'features/settings/relationship/relationship_screen.dart': 'screens/relationship_screen.dart',
    'features/settings/about/about_screen.dart': 'screens/about_screen.dart',
}

# ── 1. Detectar archivos existentes ────────────────────────────────────────
mapa_efectivo = {}
for viejo, nuevo in MAPA.items():
    if (LIB / viejo).exists():
        mapa_efectivo[viejo] = nuevo

if not mapa_efectivo:
    print('No hay archivos que mover. Nada que hacer.')
    sys.exit(0)

# ── 2. Verificar conflictos ────────────────────────────────────────────────
destinos = {}
conflictos = []
for viejo, nuevo in mapa_efectivo.items():
    if nuevo in destinos:
        conflictos.append((destinos[nuevo], viejo, nuevo))
    destinos[nuevo] = viejo

if conflictos:
    print('ERROR: dos archivos mapean al mismo destino:')
    for a, b, dest in conflictos:
        print(f'  {a} y {b} -> {dest}')
    print('Abortando para no perder datos. Revisa el mapa.')
    sys.exit(1)

for nuevo in destinos:
    if (LIB / nuevo).exists():
        print(f'ERROR: el destino {nuevo} ya existe. Abortando.')
        sys.exit(1)

print(f'Archivos a mover: {len(mapa_efectivo)}')
for v, n in mapa_efectivo.items():
    print(f'  {v} -> {n}')
print()

# ── 3. Regex de imports ────────────────────────────────────────────────────
IMPORT_RE = re.compile(
    r"""^(\s*(?:import|export)\s+)(['"])([^'"]+)(\2)([^;\n]*;?[ \t]*)$""",
    re.MULTILINE,
)


def es_relativo(imp: str) -> bool:
    return imp.startswith('./') or imp.startswith('../')


def resolver(origen: Path, imp: str) -> Path:
    """Resuelve un import relativo a path absoluto."""
    return (origen.parent / imp).resolve()


def a_ruta_lib(p: Path):
    try:
        return p.relative_to(LIB)
    except ValueError:
        return None


def rel_import(origen: Path, target: Path) -> str:
    """Calcula import relativo desde el directorio de origen hasta target."""
    rel = os.path.relpath(target, origen.parent).replace('\\', '/')
    if not rel.startswith('.'):
        rel = './' + rel
    return rel


# ── 4. Leer todos los .dart de lib/ ────────────────────────────────────────
archivos_dart = list(LIB.rglob('*.dart'))
print(f'Total .dart en lib/: {len(archivos_dart)}\n')

contenidos = {p: p.read_text(encoding='utf-8') for p in archivos_dart}

# ── 5. Calcular nuevos contenidos ──────────────────────────────────────────
nuevos_contenidos = {}
for archivo, contenido in contenidos.items():
    archivo_rel_lib = str(archivo.relative_to(LIB)).replace('\\', '/')
    nueva_rel_lib = mapa_efectivo.get(archivo_rel_lib, archivo_rel_lib)
    nueva_ubicacion = LIB / nueva_rel_lib

    def reemplazar(match):
        prefijo = match.group(1)
        comilla = match.group(2)
        imp = match.group(3)
        sufijo = match.group(4) + match.group(5)

        if not es_relativo(imp):
            return match.group(0)

        try:
            target_actual = resolver(archivo, imp)
        except Exception:
            return match.group(0)

        target_rel_lib = a_ruta_lib(target_actual)
        if target_rel_lib is None:
            return match.group(0)

        target_rel_str = str(target_rel_lib).replace('\\', '/')
        target_nuevo_rel_lib = mapa_efectivo.get(target_rel_str, target_rel_str)
        target_nuevo = LIB / target_nuevo_rel_lib

        nuevo_imp = rel_import(nueva_ubicacion, target_nuevo)
        return f'{prefijo}{comilla}{nuevo_imp}{comilla}{sufijo}'

    nuevo_contenido = IMPORT_RE.sub(reemplazar, contenido)
    if nuevo_contenido != contenido:
        nuevos_contenidos[archivo] = nuevo_contenido

# ── 6. Aplicar cambios ─────────────────────────────────────────────────────
if DRY_RUN:
    print('[DRY RUN] No se modifica nada.\n')
    print(f'Archivos con imports a reescribir: {len(nuevos_contenidos)}')
    for a in nuevos_contenidos:
        rel = str(a.relative_to(LIB)).replace('\\', '/')
        print(f'  {rel}')
    print('\n[DRY RUN] Fin. Ejecuta con dry_run=false para aplicar.')
    sys.exit(0)

# Mover archivos
for viejo, nuevo in mapa_efectivo.items():
    origen = LIB / viejo
    destino = LIB / nuevo
    destino.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(origen), str(destino))
    print(f'Movido: {viejo} -> {nuevo}')

# Escribir contenidos actualizados (en la nueva ubicación)
for archivo_viejo, contenido in nuevos_contenidos.items():
    rel_viejo = str(archivo_viejo.relative_to(LIB)).replace('\\', '/')
    rel_nuevo = mapa_efectivo.get(rel_viejo, rel_viejo)
    destino = LIB / rel_nuevo
    if destino.exists():
        destino.write_text(contenido, encoding='utf-8')
        print(f'Imports actualizados: {rel_nuevo}')

# Borrar carpetas vacías (de más profunda a menos)
for d in sorted(
    [p for p in LIB.rglob('*') if p.is_dir()],
    key=lambda x: len(x.parts),
    reverse=True,
):
    if d.exists() and not any(d.iterdir()):
        d.rmdir()
        print(f'Carpeta vacía borrada: {d.relative_to(REPO)}')

print('\n✓ Reorganización completada.')