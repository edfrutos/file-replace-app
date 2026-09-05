# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).
Este proyecto usa versionado semántico.

## [Sin publicar]

### Añadido

- **Mostrar en Finder** sobre cada resultado de búsqueda: revela el archivo ya
  seleccionado en su carpeta contenedora (`NSWorkspace.activateFileViewerSelecting`).
  Si el archivo ya no existe, informa del error sin abrir Finder.
- **Ver contenido** sobre cada resultado de búsqueda: abre una hoja de solo lectura
  con el contenido íntegro del archivo y resalta todas las coincidencias del texto
  buscado (antes solo se veía un fragmento corto alrededor de la primera coincidencia).
  Reutiliza las mismas validaciones de UTF-8 y tamaño máximo que la búsqueda; si el
  archivo cambió, se borró o creció por encima del límite desde la búsqueda, la hoja
  muestra el error correspondiente en vez del contenido.
- `FileReplaceService.readFullContent(at:maxBytes:)`: nuevo método público que expone
  la lectura de texto UTF-8 estricto ya usada internamente por `search`.

## [1.2.0] - 2026-08-28

Distribución limitada para Apple Silicon. Firma ad-hoc, sin notarización.

### Añadido

- **Alcance de búsqueda ampliado.** La búsqueda ya no exige un nombre de archivo exacto:
  recorre todos los archivos del directorio (o del árbol hasta la profundidad indicada).
- **Filtro de nombre opcional** con patrón glob POSIX (`*.js`, `config*`, `.env*`).
  Vacío = todos los archivos del alcance.
- La búsqueda recursiva incluye archivos ocultos y **poda directorios de ruido**
  (`.git`, `.hg`, `.svn`, `.build`, `.swiftpm`, `DerivedData`, `node_modules`,
  `.venv`, `venv`, `__pycache__`, `.mypy_cache`, `.pytest_cache`).
- `SearchReport` informa de `skippedFiles` (omitidos) y `reachedResultLimit`.
- Campo de texto para **escribir o pegar la ruta** del directorio, además del panel del sistema.
- `ReplacerBuildInfo.version` como fuente única de la versión de la app.

### Cambiado

- En lugar de filtrar por extensión, se intenta leer cada archivo y se **omiten**
  binarios, contenido no UTF‑8 y archivos de más de 5 MB, sin abortar la búsqueda entera.
- Tras una búsqueda **ningún resultado queda preseleccionado**: hay que marcar los
  archivos antes de poder reemplazar.
- Búsqueda y reemplazo se ejecutan **fuera del hilo principal**: la ventana no se congela.
- Los campos "Texto a buscar" / "Texto de reemplazo" usan un `NSTextView` con comillas
  curvas, guiones largos, autocorrección y reemplazo de texto **desactivados**, para
  coincidencia de cadena exacta.
- El panel lateral es un split fijo **siempre visible** (antes `NavigationSplitView`,
  que arrancaba colapsado en macOS 26/27).
- `build-macos-app.sh` y `build-dmg.sh` leen la versión de `ReplacerBuildInfo.swift`;
  `CFBundleVersion` pasa a `3`.

### Corregido

- **Crash al arrancar la app empaquetada.** `Bundle.module` fallaba con `_assertionFailure`
  porque el script de empaquetado nunca copiaba el bundle de recursos de SwiftPM dentro
  del `.app`. Se elimina por completo la dependencia de `Bundle.module` (versión e icono
  ya no son recursos del bundle).
- El panel de selección de carpeta y los campos de texto perdían el foco de forma
  intermitente; `NSApp.activate()` antes del panel y bordes decorativos que ya no
  interceptan el clic. (El foco fiable sigue requiriendo ejecutar la app empaquetada,
  no `swift run`.)
- Antes de reemplazar se comprueba que el archivo sea escribible: los de solo lectura
  se informan como error por archivo y **no** generan backup ni se modifican.
- Los propios `.replacer-backup` nunca son objetivo de búsqueda ni de reemplazo.

### Interno

- `FileReplaceError`: nuevos casos `noFilesFound`, `fileTooLarge`, `notWritable`;
  eliminados `emptyFilename` y `fileNotFound`.
- Tests de `FileReplaceCore`: 10 (2 de `AppVersion`, 8 de `FileReplaceService`).
- `.gitignore`: se ignoran `*.replacer-backup`, `*.replacer-backup-*` y el archivo `Icon?` de macOS.
- `generate-icon.swift` ya no escribe el PNG de vista previa eliminado.

## [1.1.0] - 2026-06-18

- Preparación de distribución limitada: DMG firmado ad-hoc para Apple Silicon.
- Acceso manual a la página privada de GitHub Releases desde la app.
- Checklist de validación manual.

## [1.0.0] - 2026-06

- Primera versión: app macOS SwiftUI con módulo core testeable y versión Flask heredada.

[1.2.0]: https://github.com/edfrutos/file-replace-app/releases/tag/v1.2.0
[1.1.0]: https://github.com/edfrutos/file-replace-app/releases/tag/v1.1.0
[1.0.0]: https://github.com/edfrutos/file-replace-app/releases/tag/v1.0.0
