#!/usr/bin/env python3
"""
Aplicación de búsqueda y reemplazo en archivos del sistema.
"""

import os
from flask import Flask, request, jsonify, send_from_directory

app = Flask(__name__, static_folder="static")
ALLOWED_REPLACE_PATHS = set()


def find_files(directory: str, filename: str, recursive: bool, max_depth: int) -> list:
    """Localiza archivos con el nombre dado. Devuelve lista de rutas absolutas."""
    matches = []
    directory = os.path.abspath(directory)

    if not recursive:
        fp = os.path.join(directory, filename)
        if os.path.isfile(fp):
            matches.append(fp)
        return matches

    for root, dirs, files in os.walk(directory):
        # Calcular profundidad actual respecto al directorio raíz
        depth = root[len(directory):].count(os.sep)
        if depth >= max_depth:
            dirs[:] = []  # No descender más
            continue
        if filename in files:
            matches.append(os.path.join(root, filename))
        # Limitar resultados para no colgar la app
        if len(matches) >= 50:
            break

    return matches


def find_in_file(filepath: str, search_str: str) -> dict:
    """Busca una cadena en el archivo y devuelve información sobre las coincidencias."""
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()
    except PermissionError:
        return {"error": "Sin permiso de lectura para este archivo."}
    except IsADirectoryError:
        return {"error": "La ruta especificada es un directorio, no un archivo."}
    except Exception as e:
        return {"error": f"Error al leer el archivo: {str(e)}"}

    count = content.count(search_str)
    if count == 0:
        return {"found": False, "count": 0, "preview": None}

    # Generar preview con contexto alrededor de la primera coincidencia
    idx = content.find(search_str)
    start = max(0, idx - 80)
    end = min(len(content), idx + len(search_str) + 80)
    snippet = content[start:end].replace("\n", "↵")
    # Marcar la coincidencia en el snippet
    rel_idx = idx - start
    preview = (
        snippet[:rel_idx]
        + ">>>>"
        + snippet[rel_idx : rel_idx + len(search_str)]
        + "<<<<"
        + snippet[rel_idx + len(search_str) :]
    )

    return {"found": True, "count": count, "preview": preview}


def replace_in_file(filepath: str, search_str: str, replace_str: str) -> dict:
    """Reemplaza todas las coincidencias de search_str por replace_str en el archivo."""
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()
    except Exception as e:
        return {"error": f"Error al leer el archivo: {str(e)}"}

    count = content.count(search_str)
    if count == 0:
        return {"error": "La cadena ya no existe en el archivo (puede haber cambiado)."}

    new_content = content.replace(search_str, replace_str)

    try:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(new_content)
    except PermissionError:
        return {"error": "Sin permiso de escritura para este archivo."}
    except Exception as e:
        return {"error": f"Error al escribir el archivo: {str(e)}"}

    return {"success": True, "replacements": count}


@app.route("/")
def index():
    return send_from_directory("static", "index.html")


@app.route("/api/search", methods=["POST"])
def api_search():
    data = request.get_json()
    directory  = data.get("directory", "").strip()
    filename   = data.get("filename", "").strip()
    search_str = data.get("search", "")
    recursive  = bool(data.get("recursive", False))
    max_depth  = int(data.get("max_depth", 5))

    if not directory:
        return jsonify({"error": "El directorio no puede estar vacío."})
    if not filename:
        return jsonify({"error": "El nombre de archivo no puede estar vacío."})
    if not search_str:
        return jsonify({"error": "La cadena de búsqueda no puede estar vacía."})

    directory = os.path.expanduser(directory)
    if not os.path.isdir(directory):
        return jsonify({"error": f"El directorio '{directory}' no existe o no es accesible."})

    # Localizar archivos con ese nombre
    found_files = find_files(directory, filename, recursive, max_depth)

    if not found_files:
        msg = (
            f"El archivo '{filename}' no se encontró en '{directory}'"
            + (f" ni en sus subdirectorios (hasta {max_depth} nivel{'es' if max_depth!=1 else ''})." if recursive else ".")
        )
        return jsonify({"error": msg})

    # Buscar la cadena en cada archivo encontrado
    results = []
    for fp in found_files:
        r = find_in_file(fp, search_str)
        r["filepath"] = fp
        # Ruta relativa para mostrar en UI
        r["rel_path"] = os.path.relpath(fp, directory)
        results.append(r)

    # Filtrar solo los que tienen la cadena
    hits = [r for r in results if r.get("found")]
    ALLOWED_REPLACE_PATHS.clear()
    ALLOWED_REPLACE_PATHS.update(r["filepath"] for r in hits)

    return jsonify({
        "files_scanned": len(results),
        "hits": hits,
        "no_match_files": [r["filepath"] for r in results if not r.get("found") and not r.get("error")],
    })


@app.route("/api/replace", methods=["POST"])
def api_replace():
    data = request.get_json()
    filepath = data.get("filepath", "").strip()
    search_str = data.get("search", "")
    replace_str = data.get("replace", "")

    if not filepath or not os.path.isfile(filepath):
        return jsonify({"error": "Ruta de archivo no válida."})
    if filepath not in ALLOWED_REPLACE_PATHS:
        return jsonify({"error": "Primero debes localizar este archivo desde la búsqueda de la app."})

    result = replace_in_file(filepath, search_str, replace_str)
    return jsonify(result)


@app.route("/api/list-dir", methods=["POST"])
def api_list_dir():
    """Devuelve los archivos de un directorio para autocompletar."""
    data = request.get_json()
    directory = os.path.expanduser(data.get("directory", "").strip())

    if not os.path.isdir(directory):
        return jsonify({"files": [], "valid": False})

    try:
        files = [
            f for f in os.listdir(directory) if os.path.isfile(os.path.join(directory, f))
        ]
        files.sort()
        return jsonify({"files": files[:50], "valid": True})
    except PermissionError:
        return jsonify({"files": [], "valid": False, "error": "Sin permiso de lectura."})


if __name__ == "__main__":
    print("\n🔍 File Replace Tool")
    print("   Abre tu navegador en: http://localhost:5050\n")
    app.run(debug=False, port=5050)
