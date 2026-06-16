<!-- generated-by: gsd-doc-writer -->
# API HTTP Heredada

## Estado

Esta API pertenece a la versión Flask heredada. La app principal del proyecto es la implementación macOS nativa con SwiftUI. Mantén estos endpoints solo para compatibilidad local y pruebas manuales de la interfaz web antigua.

Servidor local:

```bash
python app.py
```

Base local:

```text
http://localhost:5050
```

## Autenticación

No hay autenticación. El servidor está pensado para uso local.

Como protección mínima, `/api/replace` solo acepta rutas que hayan sido encontradas previamente por `/api/search` en la misma ejecución del proceso Flask.

## Endpoints

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/` | Sirve `static/index.html`. |
| `POST` | `/api/list-dir` | Lista hasta 50 archivos directos de un directorio para autocompletado. |
| `POST` | `/api/search` | Busca una cadena exacta en archivos con un nombre concreto. |
| `POST` | `/api/replace` | Reemplaza la cadena en una ruta autorizada por búsqueda previa. |

## `POST /api/list-dir`

Request:

```json
{
  "directory": "~/proyecto"
}
```

Response correcta:

```json
{
  "files": ["app.py", "README.md"],
  "valid": true
}
```

Si el directorio no existe o no es accesible:

```json
{
  "files": [],
  "valid": false
}
```

## `POST /api/search`

Request:

```json
{
  "directory": "~/proyecto",
  "filename": "README.md",
  "search": "texto actual",
  "recursive": true,
  "max_depth": 5
}
```

Response con coincidencias:

```json
{
  "files_scanned": 1,
  "hits": [
    {
      "found": true,
      "count": 2,
      "preview": "contexto >>>>texto actual<<<< contexto",
      "filepath": "/ruta/absoluta/README.md",
      "rel_path": "README.md"
    }
  ],
  "no_match_files": []
}
```

Response de error:

```json
{
  "error": "La cadena de búsqueda no puede estar vacía."
}
```

## `POST /api/replace`

Request:

```json
{
  "filepath": "/ruta/absoluta/README.md",
  "search": "texto actual",
  "replace": "texto nuevo"
}
```

Response correcta:

```json
{
  "success": true,
  "replacements": 2,
  "backup_path": "/ruta/absoluta/README.md.replacer-backup"
}
```

Response de error si la ruta no fue localizada antes:

```json
{
  "error": "Primero debes localizar este archivo desde la búsqueda de la app."
}
```

## Seguridad De Datos

- Los archivos se leen como bytes y se decodifican como UTF-8 estricto.
- Los archivos con bytes nulos se rechazan.
- Los archivos no decodificables como UTF-8 se rechazan para evitar corrupción.
- Antes de escribir, se crea un backup `.replacer-backup`.
- No hay rollback automático desde la UI; el usuario debe restaurar manualmente el backup si lo necesita.
