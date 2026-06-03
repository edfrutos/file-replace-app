# Aplicación para buscar y reemplazar texto en archivos

Este repositorio contiene ahora una aplicación macOS nativa en SwiftUI y conserva la versión web original con Flask.

## App macOS nativa

```bash
swift run Replacer
```

Documentación específica: `docs/native-macos.md`.

Tests:

```bash
swift test
```

## Versión web heredada

**Estructura de archivos:**
```
file-replace-app/
├── app.py
└── static/
    └── index.html
```

**Para ejecutarla en tu Mac Studio:**

```bash
pip install flask
python app.py
# Abre http://localhost:5050
```

**Flujo de 3 pasos:**

1. **Búsqueda** — Introduces el directorio (acepta `~` y rutas absolutas), el nombre del archivo (con autocompletado al listar el directorio), la cadena a buscar y la cadena de reemplazo. Al hacer clic en *Buscar*, localiza el archivo, cuenta las coincidencias y muestra un fragmento de contexto con la cadena marcada visualmente.

2. **Confirmación** — Antes de tocar nada, muestra un resumen completo: ruta del archivo, número de coincidencias, cadena original (en rojo) y cadena de reemplazo (en verde). Debes confirmar explícitamente.

3. **Resultado** — Informa de cuántos reemplazos se realizaron, con opción de hacer otra búsqueda en el mismo archivo o reiniciar todo.

Admite cualquier carácter en las cadenas: alfanumérico, espacios, símbolos, URLs, tokens, etc.
