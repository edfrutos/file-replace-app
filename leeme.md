# Replacer

Replacer es una aplicación local para macOS que busca y reemplaza texto en archivos UTF-8. La app principal es nativa con SwiftUI; la versión web con Flask queda como legado.

## Uso Rápido

```bash
swift run Replacer
```

Documentación principal:

- `README.md`
- `docs/native-macos.md`
- `docs/ARCHITECTURE.md`
- `docs/DEVELOPMENT.md`
- `docs/TESTING.md`
- `docs/CONFIGURATION.md`
- `docs/API.md`

Tests:

```bash
swift test
```

Antes de escribir cambios, la app nativa crea una copia `.replacer-backup` junto a cada archivo seleccionado.

## Versión web heredada

La versión Flask se conserva solo por compatibilidad local. La app principal actual es la versión macOS nativa. Su API está documentada en `docs/API.md`.

**Para ejecutarla en tu Mac Studio:**

```bash
pip install flask
python app.py
# Abre http://localhost:5050
```

**Flujo de 3 pasos:**

1. **Búsqueda** — Introduces el directorio (acepta `~` y rutas absolutas), el nombre del archivo (con autocompletado al listar el directorio), la cadena a buscar y la cadena de reemplazo. Al hacer clic en *Buscar*, localiza el archivo, cuenta las coincidencias y muestra un fragmento de contexto con la cadena marcada visualmente.

2. **Confirmación** — Antes de tocar nada, muestra un resumen completo: ruta del archivo, número de coincidencias, cadena original (en rojo) y cadena de reemplazo (en verde). Debes confirmar explícitamente. Al reemplazar, crea una copia `.replacer-backup` junto al archivo original.

3. **Resultado** — Informa de cuántos reemplazos se realizaron, con opción de hacer otra búsqueda en el mismo archivo o reiniciar todo.

Admite cualquier carácter en las cadenas: alfanumérico, espacios, símbolos, URLs, tokens, etc.
