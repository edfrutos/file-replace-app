# Replacer para macOS

Replacer para macOS es la interfaz principal del proyecto. Permite buscar una cadena exacta en archivos UTF-8, revisar las coincidencias y reemplazar solo los archivos seleccionados. La versión Flask original se conserva como legado.

## Estructura

```text
Package.swift
Sources/
  FileReplaceCore/
    AppVersion.swift
    FileReplaceService.swift
  FileReplaceApp/
    FileReplaceApp.swift
    ContentView.swift
    UpdateCenter.swift
    Resources/Version.txt
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

1. Selecciona un directorio con el selector nativo de macOS.
2. Selecciona uno de los archivos de texto listados para el directorio elegido.
3. Introduce el texto a buscar y el texto de reemplazo.
4. Activa la búsqueda recursiva si necesitas revisar subdirectorios. El selector pasará a mostrar nombres únicos de archivos de texto encontrados bajo esa carpeta.
5. Ejecuta la búsqueda, revisa las previsualizaciones y desmarca los archivos que no quieras modificar.
6. Pulsa `Reemplazar seleccionados` y confirma la operación. Replacer creará una copia `.replacer-backup` junto a cada archivo antes de escribir.

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
