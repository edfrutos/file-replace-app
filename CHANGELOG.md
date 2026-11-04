# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).
Este proyecto usa versionado semántico.

## [1.4.0] - Sin publicar

### Añadido

- **Varios pares «buscar → reemplazar»** aplicados en una sola pasada, sin
  encadenarse. Si dos coincidencias se solapan, gana la que empieza antes y, en la
  misma posición, el par de más arriba.
- **Recetas**: guardar los pares actuales con un nombre, cargarlas y eliminarlas
  (`UserDefaults`, clave `replacerRecipes`), e **importar pares desde CSV/TSV**
  (coma, punto y coma o tabulador; comillas; cabecera opcional).
- **Revisión por coincidencia**: cada resultado muestra sus apariciones con línea y
  el cambio antes → después; se pueden excluir una a una.
- Aviso cuando se edita el texto a buscar tras la búsqueda: hay que volver a buscar
  para poder reemplazar.
- **Historial de reemplazos** (botón «Historial»): los últimos 50 lotes con fecha,
  carpeta, pares y archivos. Se puede **restaurar** un lote entero o un archivo
  suelto desde su `.replacer-backup`, solo si el archivo no se ha modificado después
  del reemplazo. Se guarda en `Application Support/Replacer/history.json` con un
  marcador de seguridad de la carpeta para restaurar tras reiniciar la app.
- **Arrastrar una carpeta** a la ventana para elegirla como directorio de búsqueda.
  Los archivos sueltos y los paquetes (apps, documentos de Pages) se rechazan con
  un aviso.
- **Integración con Finder**: servicio «Buscar y reemplazar con Replacer» (clic
  derecho en una carpeta ▸ Servicios) y carpetas soltadas en el icono del Dock,
  también con la app cerrada. Replacer se declara para carpetas con rango
  `Alternate`, así que no pasa a ser la app por defecto.
- **Interfaz en inglés.** Replacer usa el primero de los idiomas preferidos que
  sea español o inglés (inglés si no hay ninguno). Nueva opción **Idioma** en
  Ajustes (Sistema, Español, English), con botón para reiniciar la app y aplicarlo.
- **Empezar de nuevo** (botón en la cabecera y `Archivo ▸ Empezar de nuevo`, ⌘N):
  vacía carpeta, pares, filtro y resultados sin cerrar la app; conserva historial
  y recetas.

### Cambiado

- Antes de escribir se comprueba que el archivo no haya cambiado desde la búsqueda
  (huella FNV-1a del contenido); si cambió, se informa y no se toca.

### Interno

- `FileReplaceService`: `ReplacementRule`, `MatchOccurrence`,
  `search(…rules:…)` y `replace(in:rules:excludingOccurrences:)`; nuevos errores
  `fileChangedSinceSearch` y `nothingSelected`. `RuleList.swift` con
  `ReplacementRecipe` y `RuleListParser`.
- `ReplacementHistory.swift` (`ReplacementBatch`, `ReplacementHistoryStore`) y
  `FileReplaceService.restore(_:)`; nuevos errores `backupMissing` y
  `fileChangedSinceReplacement`.
- Entitlement `com.apple.security.files.bookmarks.app-scope`; el target de Xcode
  usa ya `Sources/FileReplaceApp/Replacer.entitlements` (`CODE_SIGN_ENTITLEMENTS`).
- `Replacer/Replacer-Info.plist` (`INFOPLIST_FILE`) con `CFBundleDocumentTypes`
  y `NSServices`; Xcode lo fusiona con el Info.plist generado.
  `build-macos-app.sh` añade las mismas claves al DMG.
- `Localization.swift`: `AppLanguage` y `tr("español", "English")`; los textos
  van en el código porque el ejecutable de SwiftPM no empaqueta recursos. Los
  mensajes de `FileReplaceError` también se traducen.
- `CFBundleLocalizations` (`es`, `en`), región `en` en el proyecto de Xcode y
  `en.lproj/ServicesMenu.strings` para el nombre del servicio.
- `FileReplaceViewModel` vive en `FileReplaceApp` para que los comandos de menú
  lleguen a él; `AppDelegate` es `@MainActor`.
- `Package.swift` excluye `Replacer.entitlements` del target de SwiftPM.
- Tests de `FileReplaceCore`: 31.

## [1.3.1] - Sin publicar

### Cambiado

- Vuelve el icono de cuero, ya ajustado a la rejilla de macOS (margen, esquinas
  transparentes y sombra). `scripts/generate-icon.swift` lo escala desde
  `Assets/AppIcon/Replacer-master.png` en vez de dibujar el glifo azul.

### Corregido

- Ajustes: la etiqueta «Apariencia» se recortaba a su primera letra porque el
  control segmentado ocupaba todo el ancho de la ventana.

### Interno

- Target de Xcode: versión `1.3.1`, build `4`.
- `build-macos-app.sh`: `CFBundleVersion` pasa a `5`.

## [1.3.0] - 2026-09-06

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
- **Modo oscuro** y preferencia de **Apariencia** (`Replacer ▸ Ajustes…`: Claro,
  Oscuro o Automático). Se aplica a toda la app, incluidos paneles, alertas y barra
  de título (`NSApp.appearance`), y se guarda en `UserDefaults`
  (`replacerAppearanceMode`).
- Botón **Limpiar resultados** en la barra de resultados: vacía la lista, la
  selección y el informe sin perder directorio ni textos.
- **Target de Xcode para el Mac App Store** (`Replacer/Replacer.xcodeproj`, scheme
  compartido `Replacer App Store`), con sandbox y compilado con `APPSTORE_BUILD`:
  oculta el campo de ruta escrita a mano y el botón de actualizaciones.

### Cambiado

- Tras reemplazar, la lista de resultados se actualiza repitiendo la última búsqueda,
  así que los archivos ya reemplazados desaparecen o muestran el conteo nuevo.
- `Limpiar selección` pasa a llamarse `Deseleccionar todo`; `Seleccionar todo` y
  `Deseleccionar todo` se desactivan cuando no tienen efecto.
- Icono nuevo dibujado en código (`scripts/generate-icon.swift`) a partir del glifo
  azul de la app; sustituye al icono anterior.
- Barra lateral más compacta para que `Reemplazar seleccionados` quepa sin scroll en
  una ventana de 900 pt de alto.
- Se desactivan las pestañas de ventana de macOS (la app usa una sola ventana).

### Interno

- Tests de `FileReplaceCore`: 14 (2 de `AppVersion`, 12 de `FileReplaceService`).
- `build-macos-app.sh`: `CFBundleVersion` pasa a `4`.
- Target de Xcode: build (`CURRENT_PROJECT_VERSION`) `3`, el subido a App Store
  Connect. Numeración independiente de la del DMG.
- `scripts/captura-appstore.sh` y capturas de 2880×1800 en
  `Assets/capturas/AppleStore/`.

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

[1.3.0]: https://github.com/edfrutos/file-replace-app/releases/tag/v1.3.0
[1.2.0]: https://github.com/edfrutos/file-replace-app/releases/tag/v1.2.0
[1.1.0]: https://github.com/edfrutos/file-replace-app/releases/tag/v1.1.0
[1.0.0]: https://github.com/edfrutos/file-replace-app/releases/tag/v1.0.0
