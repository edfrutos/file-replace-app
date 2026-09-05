# Replacer para macOS

Replacer para macOS es la interfaz principal del proyecto. Permite buscar una cadena exacta en archivos UTF-8, revisar las coincidencias y reemplazar solo los archivos seleccionados. La versión Flask original se conserva como legado.

## Estructura

```text
Package.swift
Sources/
  FileReplaceCore/
    AppVersion.swift
    FileReplaceService.swift
    ReplacerBuildInfo.swift
  FileReplaceApp/
    FileReplaceApp.swift
    ContentView.swift
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

También puedes abrir la carpeta del proyecto en Xcode y ejecutar el esquema `Replacer`.

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

1. Selecciona un directorio con el selector nativo de macOS, o escribe/pega su ruta en el campo de la sección Ubicación (acepta `~`).
2. Opcional: escribe un filtro de nombre con patrón glob (`*.js`, `config*`, `.env*`). Si lo dejas vacío, la búsqueda revisa todos los archivos del alcance.
3. Introduce el texto a buscar y el texto de reemplazo.
4. Activa la búsqueda recursiva y ajusta la profundidad si necesitas revisar subdirectorios.
5. Ejecuta la búsqueda. Replacer lee cada archivo como UTF-8, omite binarios, archivos no UTF-8 y archivos mayores de 5 MB, e informa de cuántos ha omitido.
6. Ningún resultado viene marcado: revisa las previsualizaciones y marca los archivos que quieras modificar (o usa `Seleccionar todo`).
7. Sobre cada resultado, el icono de carpeta lo revela en Finder ya seleccionado, y el icono de lupa sobre documento abre una hoja de solo lectura con el contenido íntegro del archivo y todas las coincidencias resaltadas (no solo la primera). Ninguna de las dos acciones modifica archivos ni cambia la selección de reemplazo; si el archivo cambió o se borró desde la búsqueda, se informa del error.
8. Pulsa `Reemplazar seleccionados` y confirma la operación. Replacer creará una copia `.replacer-backup` junto a cada archivo antes de escribir. Los archivos de solo lectura se informan como error y no se tocan.

## Actualizaciones

El botón `Actualizaciones` y la acción `Replacer > Buscar actualizaciones…` muestran primero un diálogo con la versión instalada y explican que el acceso es privado. Tras confirmarlo, Replacer abre la página de releases en el navegador.

Este flujo está diseñado para distribución limitada: GitHub valida la sesión y los permisos del destinatario. Replacer no almacena credenciales, no consulta la API privada automáticamente y no instala actualizaciones por su cuenta.

## Seguridad

La app escribe directamente sobre los archivos seleccionados, pero antes crea una copia de seguridad junto a cada archivo con sufijo `.replacer-backup`. Rechaza binarios y archivos no UTF-8, pero conviene probar primero en una carpeta descartable o con archivos bajo control de versiones.

## Documentación Relacionada

- [Arquitectura](ARCHITECTURE.md)
- [Desarrollo](DEVELOPMENT.md)
- [Pruebas](TESTING.md)
- [Configuración](CONFIGURATION.md)
