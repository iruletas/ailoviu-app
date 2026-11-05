#!/usr/bin/env python3
"""
Aplica los cambios de Ailoviu al repo en dos fases:

  FASE 1 · Archivos: copia el contenido de ailoviu_cambios.zip y elimina
           lo que ya no sirve (OBSOLETOS).
  FASE 2 · Textos: sustituye frases viejas por nuevas en todo lib/**/*.dart
           (tabla REEMPLAZOS, más abajo). Edita la tabla a tu gusto.

Uso:
  1. Sube a la raíz del repo: este archivo + ailoviu_cambios.zip
  2. Ejecuta (local o con el workflow "Aplicar cambios"):
       DRY_RUN=true python aplicar_cambios.py   # solo muestra
       python aplicar_cambios.py                # aplica

Los reemplazos son idempotentes: si ya se aplicaron, no hacen nada.
Cada regla informa cuántas veces coincidió; las que no coinciden salen
como AVISO (el texto cambió o ya estaba aplicado).
"""

import os
import re
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
ZIP = RAIZ / "ailoviu_cambios.zip"
DRY_RUN = os.environ.get("DRY_RUN", "false").lower() == "true"
LIMPIAR = True  # borra zip y script al terminar (solo si no es simulación)

# ── Fase 1 ────────────────────────────────────────────────────────────
OBSOLETOS = [
    "lib/widgets/onboarding_role_step.dart",
]

# ── Fase 2 ────────────────────────────────────────────────────────────
# ("lit", viejo, nuevo)  → reemplazo literal (una sola línea de código).
# ("rx",  patrón, nuevo) → regex, para frases partidas en varias líneas
#                          de Dart ('...'\n  '...'). \1 = sangría.
# Regla de tono: "tu amor" donde no se sabe en qué celular se lee;
# "novia"/"novio" solo cuando el contexto es seguro.
REEMPLAZOS = [
    # Bienvenida y espacio compartido
    ("lit", "Bienvenidx a Ailoviu", "Bienvenidos a Ailoviu"),
    ("lit", "Este es el espacio de ustedes.", "Este es su rincón."),
    ("lit", "Este es el espacio de $namesLabel.", "Este es el rincón de $namesLabel."),
    ("lit", "Se mostrará en el espacio de ustedes.", "Así te verá tu amor."),
    ("lit",
     "Quien empieza aquí deja listo el espacio y muestra un QR.",
     "El primero en abrir la app deja todo listo y muestra un QR."),

    # "La otra persona" → "Tu amor"
    ("lit", "La otra persona", "Tu amor"),
    ("lit", "la otra persona", "tu amor"),

    # Pareja / miembro / integrantes
    ("lit", "vincules a tu pareja", "vincules a tu amor"),
    ("lit", "Solo tú y tu pareja tienen llave", "Solo ustedes dos tienen llave"),
    ("rx", r"con tu '\n(\s*)'pareja,", r"con tu '\n\1'amor,"),
    ("lit", "Genera un QR que el nuevo miembro escanea.",
     "Genera un QR para que tu amor lo escanee."),
    ("lit", "Comprueba los factores de seguridad del miembro",
     "Comprueba los factores de seguridad de tu amor"),
    ("lit", "'1 miembro'", "'Solo tú'"),
    ("lit", "'$approvedCount miembros'", "'Los dos vinculados'"),
    ("lit", "'este miembro'", "'tu amor'"),

    # Relación
    ("lit", "Sus nombres se guardan automáticamente.",
     "Se guardan automáticamente."),
    ("lit", "Agrega sus nombres y la fecha de inicio para empezar",
     "Agrega sus nombres y la fecha en que se hicieron novios"),
    ("lit", "desde cuándo están juntos", "desde cuándo son novios"),
]


def construir_vista_zip():
    """Contenido del zip: {ruta_relativa: bytes}."""
    vista = {}
    with zipfile.ZipFile(ZIP) as z:
        for info in z.infolist():
            if info.is_dir():
                continue
            nombre = info.filename.replace("\\", "/")
            destino = (RAIZ / nombre).resolve()
            if RAIZ not in destino.parents:
                print(f"  OMITIDO (ruta insegura): {nombre}")
                continue
            vista[nombre] = z.read(info)
    return vista


def fase_archivos(vista):
    print("FASE 1 · Archivos\n")
    nuevos = 0
    for nombre, datos in vista.items():
        destino = RAIZ / nombre
        existe = destino.exists()
        print(f"  {'REEMPLAZA' if existe else 'NUEVO    '}  {nombre}")
        nuevos += 0 if existe else 1
        if not DRY_RUN:
            destino.parent.mkdir(parents=True, exist_ok=True)
            destino.write_bytes(datos)
    eliminados = 0
    print()
    for rel in OBSOLETOS:
        p = RAIZ / rel
        if p.exists():
            print(f"  ELIMINA    {rel}")
            if not DRY_RUN:
                p.unlink()
            eliminados += 1
        else:
            print(f"  (ya no existe) {rel}")
    print(f"\n  → {len(vista)} archivos ({nuevos} nuevos), {eliminados} eliminados.\n")


def leer(rel, vista):
    """En simulación, lo que irá en disco es lo del zip."""
    if DRY_RUN and rel in vista:
        return vista[rel].decode("utf-8")
    p = RAIZ / rel
    return p.read_text(encoding="utf-8")


def fase_textos(vista):
    print("FASE 2 · Textos\n")
    rutas = {
        str(p.relative_to(RAIZ)).replace("\\", "/")
        for p in (RAIZ / "lib").rglob("*.dart")
    }
    if DRY_RUN:
        rutas |= {n for n in vista if n.endswith(".dart")}
        rutas -= set(OBSOLETOS)
    aciertos = [0] * len(REEMPLAZOS)
    archivos_tocados = 0

    for rel in sorted(rutas):
        try:
            original = leer(rel, vista)
        except FileNotFoundError:
            continue
        texto = original
        for i, (tipo, viejo, nuevo) in enumerate(REEMPLAZOS):
            if tipo == "lit":
                n = texto.count(viejo)
                if n:
                    texto = texto.replace(viejo, nuevo)
            else:
                texto, n = re.subn(viejo, nuevo, texto)
            aciertos[i] += n
        if texto != original:
            archivos_tocados += 1
            print(f"  TEXTOS     {rel}")
            if not DRY_RUN:
                (RAIZ / rel).write_text(texto, encoding="utf-8")

    print()
    for i, (tipo, viejo, nuevo) in enumerate(REEMPLAZOS):
        corto = viejo.replace("\n", "\\n")[:60]
        if aciertos[i]:
            print(f"  ✓ {aciertos[i]:>2}×  {corto}")
        else:
            print(f"  ! AVISO sin coincidencias: {corto}")
    print(f"\n  → {archivos_tocados} archivos con textos cambiados.\n")


def main() -> int:
    if not ZIP.exists():
        print(f"ERROR: no encuentro {ZIP.name} en la raíz del repo.")
        return 1
    if not (RAIZ / "pubspec.yaml").exists():
        print("ERROR: esta no parece la raíz del repo (falta pubspec.yaml).")
        return 1

    print("== SIMULACIÓN (no se escribe nada) ==\n" if DRY_RUN else "== APLICANDO ==\n")
    vista = construir_vista_zip()
    fase_archivos(vista)
    fase_textos(vista)

    if not DRY_RUN and LIMPIAR:
        ZIP.unlink()
        Path(__file__).resolve().unlink()
        print("Limpieza: zip y script borrados.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
