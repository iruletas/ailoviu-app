#!/usr/bin/env python3
"""
Exporta el contenido del repositorio scrobbot-app a un JSON único.
Pensado para dar contexto completo a chats nuevos (IA) sin explicaciones adicionales.

- Recorre todo el repo respetando .gitignore básico.
- Recorta archivos .json grandes a una muestra de 5 elementos.
- Ignora carpetas de build, caché, dependencias.
- El JSON resultante se sube como artifact descargable desde GitHub Actions.
"""

import json
from pathlib import Path

# Directorios a ignorar por completo (build, caché, dependencias)
IGNORAR_RUTAS = {
    ".git",
    "__pycache__",
    ".pytest_cache",
    ".venv",
    "venv",
    ".dart_tool",
    "build",
    ".gradle",
    "node_modules",
    ".idea",
    ".vscode",
}

# Nombres de archivo a ignorar (por nombre exacto)
IGNORAR_ARCHIVOS = {
    ".DS_Store",
    "Thumbs.db",
    "proyecto_completo.json",
}

# Máximo de elementos a mostrar en archivos .json grandes
MAX_ITEMS_MUESTRA_JSON = 5

# Extensiones que se exportan completas (código y texto plano)
EXTENSIONES_TEXTO = {
    ".py", ".dart", ".yaml", ".yml", ".md", ".txt",
    ".json", ".xml", ".gradle", ".properties",
    ".kt", ".java", ".sh", ".html", ".css", ".js",
    ".gitignore",
}

# Nombres de archivo sin extensión que también son texto
ARCHIVOS_SIN_EXTENSION_TEXTO = {
    ".gitignore",
    "gradlew",
    "gradlew.bat",
}


def es_archivo_texto(path: Path) -> bool:
    """Determina si un archivo debe exportarse como texto completo."""
    if path.name in ARCHIVOS_SIN_EXTENSION_TEXTO:
        return True
    return path.suffix.lower() in EXTENSIONES_TEXTO


def procesar_json_muestra(contenido_texto: str, max_items: int = MAX_ITEMS_MUESTRA_JSON):
    """Reduce un JSON (lista o dict) a una muestra pequeña para no inflar el export."""
    try:
        data = json.loads(contenido_texto)
    except Exception:
        return contenido_texto

    if isinstance(data, list):
        total = len(data)
        muestra = data[:max_items]
        return {
            "_info_muestra": (
                f"[MUESTRA RECORTADA: Mostrando {len(muestra)} de {total} elementos totales]"
            ),
            "contenido": muestra,
        }
    if isinstance(data, dict):
        total = len(data)
        claves = list(data.keys())[:max_items]
        muestra = {k: data[k] for k in claves}
        return {
            "_info_muestra": (
                f"[MUESTRA RECORTADA: Mostrando {len(muestra)} de {total} llaves totales]"
            ),
            "contenido": muestra,
        }

    return contenido_texto


def construir_mapa_jerarquia(raiz: Path):
    """Genera el árbol de carpetas y archivos del repo, para vista rápida."""
    arbol = {}
    for path in sorted(raiz.rglob("*")):
        if any(part in IGNORAR_RUTAS for part in path.parts):
            continue
        if path.name in IGNORAR_ARCHIVOS:
            continue

        partes = path.relative_to(raiz).parts
        nodo_actual = arbol
        for i, parte in enumerate(partes):
            if i == len(partes) - 1:
                if path.is_file():
                    nodo_actual[parte] = "[ARCHIVO]"
                else:
                    nodo_actual.setdefault(parte, {})
            else:
                nodo_actual = nodo_actual.setdefault(parte, {})
    return arbol


def agrupar_por_origen(ruta_relativa: str) -> str:
    """
    Agrupa archivos por origen: app, bot, tools, config, otros.
    Se usa para ordenar la salida y que sea legible.
    """
    if ruta_relativa.startswith("lib/") or ruta_relativa.startswith("android/"):
        return "app"
    if ruta_relativa.startswith("bot/"):
        return "bot"
    if ruta_relativa.startswith("tools/"):
        return "tools"
    if ruta_relativa.startswith(".github/"):
        return "config_github"
    if ruta_relativa in {"pubspec.yaml", ".gitignore", "ESTADO.md"}:
        return "config_raiz"
    return "otros"


def exportar_repositorio(ruta_salida: str = "proyecto_completo.json"):
    raiz = Path(".")

    proyecto_dict = {
        "_ESTRUCTURA_DEL_REPOSITORIO": construir_mapa_jerarquia(raiz),
        "_RESUMEN_POR_ORIGEN": {
            "app": [],
            "bot": [],
            "tools": [],
            "config_github": [],
            "config_raiz": [],
            "otros": [],
        },
        "archivos_del_proyecto": {},
    }

    for path in sorted(raiz.rglob("*")):
        if any(part in IGNORAR_RUTAS for part in path.parts):
            continue
        if not path.is_file():
            continue

        ruta_relativa = str(path.relative_to(raiz))
        if path.name in IGNORAR_ARCHIVOS:
            continue
        if path.name == ruta_salida:
            continue

        # Registrar en resumen por origen
        grupo = agrupar_por_origen(ruta_relativa)
        proyecto_dict["_RESUMEN_POR_ORIGEN"][grupo].append(ruta_relativa)

        # Leer y procesar contenido
        if es_archivo_texto(path):
            try:
                contenido = path.read_text(encoding="utf-8")
                if path.suffix.lower() == ".json":
                    contenido = procesar_json_muestra(contenido)
                proyecto_dict["archivos_del_proyecto"][ruta_relativa] = contenido
            except UnicodeDecodeError:
                proyecto_dict["archivos_del_proyecto"][ruta_relativa] = (
                    "[Archivo de texto con encoding no UTF-8, omitido]"
                )
            except Exception as e:
                proyecto_dict["archivos_del_proyecto"][ruta_relativa] = (
                    f"[Error al leer: {e}]"
                )
        else:
            proyecto_dict["archivos_del_proyecto"][ruta_relativa] = (
                "[Archivo binario o de extensión no contemplada]"
            )

    Path(ruta_salida).write_text(
        json.dumps(proyecto_dict, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    total = len(proyecto_dict["archivos_del_proyecto"])
    print(f"✓ Repositorio exportado a '{ruta_salida}'")
    print(f"✓ Total de archivos incluidos: {total}")
    for grupo, archivos in proyecto_dict["_RESUMEN_POR_ORIGEN"].items():
        if archivos:
            print(f"  - {grupo}: {len(archivos)} archivos")


if __name__ == "__main__":
    exportar_repositorio()