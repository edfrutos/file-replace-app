# Replacer para macOS

Este proyecto conserva la versión Flask original y añade una implementación nativa para macOS con SwiftUI.

## Estructura

```text
Package.swift
Sources/
  FileReplaceCore/
    FileReplaceService.swift
  FileReplaceApp/
    FileReplaceApp.swift
    ContentView.swift
Tests/
  FileReplaceCoreTests/
    FileReplaceCoreTests.swift
```

`FileReplaceCore` contiene la lógica de búsqueda, conteo y reemplazo en archivos UTF-8. `FileReplaceApp` contiene la interfaz nativa SwiftUI. Los tests cubren la lógica de filesystem con directorios temporales.

## Ejecutar

```bash
swift run Replacer
```

También puedes abrir la carpeta del proyecto en Xcode y ejecutar el esquema `Replacer`.

## Crear paquete `.app`

```bash
scripts/build-macos-app.sh
```

El script compila en modo release y crea `dist/Replacer.app`.

## Probar

```bash
swift test
```

Los tests crean archivos temporales y no modifican el contenido real del repositorio.

## Flujo de uso

1. Selecciona un directorio con el selector nativo de macOS.
2. Selecciona uno de los archivos listados para el directorio elegido.
3. Introduce el texto a buscar y el texto de reemplazo.
4. Activa la búsqueda recursiva si necesitas revisar subdirectorios.
5. Ejecuta la búsqueda, revisa las previsualizaciones y desmarca los archivos que no quieras modificar.
6. Pulsa `Reemplazar seleccionados` y confirma la operación.

## Seguridad

La app escribe directamente sobre los archivos seleccionados y no crea copias de seguridad. Prueba primero en una carpeta descartable o con archivos bajo control de versiones.
