# Replacer para macOS

Replacer para macOS es la interfaz principal del proyecto. Permite buscar una o varias cadenas exactas en archivos UTF-8, revisar cada coincidencia y reemplazar solo lo que el usuario marca, con copia de seguridad e historial para deshacer. La versión Flask original se conserva como legado.

## Estructura

```text
Package.swift
Sources/
  FileReplaceCore/
    AppVersion.swift
    FileReplaceService.swift      # Búsqueda, reemplazo y restauración
    Localization.swift            # tr("español", "English")
    ReplacementHistory.swift      # Lotes del historial y su almacén JSON
    ReplacerBuildInfo.swift
    RuleList.swift                # Recetas e importación CSV/TSV
  FileReplaceApp/
    FileReplaceApp.swift          # App, Ajustes, menú y servicio de Finder
    ContentView.swift
    RulesEditor.swift             # Pares y menú de recetas
    OccurrenceReview.swift        # Revisión coincidencia a coincidencia
    ReplacementHistoryView.swift  # Hoja del historial
    UpdateCenter.swift
Tests/
  FileReplaceCoreTests/
    FileReplaceCoreTests.swift
```

`FileReplaceCore` contiene la lógica de búsqueda, conteo y reemplazo en archivos UTF-8. `FileReplaceApp` contiene la interfaz nativa SwiftUI. Los tests cubren la lógica de filesystem con directorios temporales.

## Requisitos

- macOS 14 o superior.
- SwiftPM disponible desde Xcode o Xcode Command Line Tools.

## Ejecutar

```bash
swift run Replacer
```

También puedes abrir la carpeta del proyecto en Xcode y ejecutar el esquema `Replacer`: es el binario SwiftPM/DMG. Para la versión del Mac App Store abre `Replacer/Replacer.xcodeproj` y usa el scheme `Replacer App Store` (ver [APP_STORE_SUBMISSION.md](APP_STORE_SUBMISSION.md)).

Nota: al ejecutar con `swift run` (binario sin bundle), el panel nativo de selección de carpetas puede no aparecer, porque macOS lo sirve desde un proceso aparte que necesita un `Info.plist`. En ese caso, usa el campo de texto de la sección **Ubicación** para escribir o pegar la ruta del directorio, o ejecuta la app empaquetada (`scripts/build-macos-app.sh` y abre `dist/Replacer.app`).

## Crear paquete `.app`

```bash
scripts/build-macos-app.sh
```

El script genera el icono, compila en modo release y crea `dist/Replacer.app`.

La firma actual es ad-hoc y no está notarizada. En otro Mac, el destinatario debe verificar el origen del DMG, arrastrar la app a `/Applications` y usar `Abrir` desde el menú contextual la primera vez. Si Gatekeeper sigue bloqueándola, puede autorizarla desde Ajustes del Sistema > Privacidad y seguridad. Este procedimiento solo es apropiado para distribución limitada y de confianza.

## Probar

```bash
swift test
```

Los tests crean archivos temporales y no modifican el contenido real del repositorio.

## Flujo de uso

1. Elige la carpeta: con el selector nativo, arrastrándola a la ventana, soltándola en el icono del Dock o con clic derecho en Finder ▸ Servicios ▸ `Buscar y reemplazar con Replacer`. En el build SwiftPM/DMG también puedes escribir o pegar su ruta en la sección Ubicación (acepta `~`).
2. Opcional: escribe un filtro de nombre con patrón glob (`*.js`, `config*`, `.env*`). Si lo dejas vacío, la búsqueda revisa todos los archivos del alcance.
3. Introduce el texto a buscar y el texto de reemplazo. `Añadir par` añade más pares: todos se aplican en una sola pasada y no se encadenan (con `A→B` y `B→C`, una `A` acaba en `B`). Si dos coincidencias se solapan, gana la que empieza antes y, en la misma posición, el par de más arriba. El menú `Recetas` guarda los pares con un nombre, los vuelve a cargar e importa pares desde un CSV/TSV (columna 1 buscar, columna 2 reemplazar; coma, punto y coma o tabulador).
4. Activa la búsqueda recursiva y ajusta la profundidad si necesitas revisar subdirectorios.
5. Ejecuta la búsqueda. Replacer lee cada archivo como UTF-8, omite binarios, archivos no UTF-8 y archivos mayores de 5 MB, e informa de cuántos ha omitido.
6. Ningún resultado viene marcado: revisa las previsualizaciones y marca los archivos que quieras modificar (o usa `Seleccionar todo` / `Deseleccionar todo`). `Revisar coincidencias una a una` despliega cada aparición con su línea y el cambio (original tachado, nuevo texto en verde); desmarca las que no quieras tocar. `Limpiar resultados` vacía la lista sin perder directorio ni textos. Si cambias un texto a buscar después de buscar, la app avisa y no deja reemplazar hasta que vuelvas a buscar.
7. Sobre cada resultado, el icono de carpeta lo revela en Finder ya seleccionado, y el icono de lupa sobre documento abre una hoja de solo lectura con el contenido íntegro del archivo y todas las coincidencias resaltadas (no solo la primera). Ninguna de las dos acciones modifica archivos ni cambia la selección de reemplazo; si el archivo cambió o se borró desde la búsqueda, se informa del error.
8. Pulsa `Reemplazar seleccionados` y confirma la operación. Replacer creará una copia `.replacer-backup` junto a cada archivo antes de escribir. Los archivos de solo lectura, y los que han cambiado desde la búsqueda, se informan como error y no se tocan.
9. Al terminar, Replacer repite la última búsqueda para que la lista refleje el estado actual de los archivos.
10. `Empezar de nuevo` (o ⌘N) deja la ventana vacía para otra búsqueda sin cerrar la app; conserva el historial y las recetas.

## Historial y restauración

El botón `Historial` muestra los últimos 50 reemplazos con fecha, carpeta, pares y archivos. `Restaurar todo` devuelve los archivos de un lote a su `.replacer-backup`; con `Ver archivos` se restaura uno suelto. Un archivo solo se restaura si sigue exactamente como lo dejó el reemplazo: si se ha editado después, se deja como está y se informa. Las copias de seguridad se conservan, y `Vaciar historial` no las borra.

Con sandbox, Replacer guarda un marcador de seguridad de cada carpeta para poder restaurar tras reiniciar la app. Si el marcador ya no sirve (carpeta movida), pide volver a elegir la carpeta.

## Idioma

La interfaz está en español e inglés. Por defecto usa el primero de los idiomas preferidos del sistema que sea uno de los dos (inglés si no hay ninguno). `Replacer ▸ Ajustes… ▸ Idioma` permite fijarlo (Sistema, Español, English); como macOS solo aplica el idioma al arrancar, ofrece `Reiniciar ahora`.

## Apariencia

`Replacer ▸ Ajustes…` permite elegir Claro, Oscuro o Automático (sigue al sistema). La elección se aplica a toda la app, incluidos paneles y alertas, y se recuerda entre sesiones. No afecta a otras apps: la ventana de Finder que abre «Mostrar en Finder» sigue la apariencia del sistema.

## Actualizaciones

Solo en el build SwiftPM/DMG; la versión del Mac App Store no incluye este botón.

El botón `Actualizaciones` y la acción `Replacer > Buscar actualizaciones…` muestran primero un diálogo con la versión instalada y explican que el acceso es privado. Tras confirmarlo, Replacer abre la página de releases en el navegador.

Este flujo está diseñado para distribución limitada: GitHub valida la sesión y los permisos del destinatario. Replacer no almacena credenciales, no consulta la API privada automáticamente y no instala actualizaciones por su cuenta.

## Seguridad

La app escribe directamente sobre los archivos seleccionados, pero antes crea una copia de seguridad junto a cada archivo con sufijo `.replacer-backup`. Rechaza binarios y archivos no UTF-8, pero conviene probar primero en una carpeta descartable o con archivos bajo control de versiones.

## Documentación Relacionada

- [Arquitectura](ARCHITECTURE.md)
- [Desarrollo](DEVELOPMENT.md)
- [Pruebas](TESTING.md)
- [Configuración](CONFIGURATION.md)
