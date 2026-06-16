# Replacer

Replacer es una utilidad local para macOS que busca, revisa y reemplaza texto en archivos UTF-8 con confirmación explícita y copias de seguridad automáticas.

La app principal está escrita en SwiftUI y usa un módulo core testeable para localizar archivos, contar coincidencias, rechazar contenido no editable y escribir reemplazos. La versión Flask se conserva como interfaz web heredada.

## Estructura

```text
Package.swift
Sources/
  FileReplaceApp/       # App macOS SwiftUI
  FileReplaceCore/      # Lógica de búsqueda y reemplazo
Tests/
  FileReplaceCoreTests/ # Tests unitarios con directorios temporales
scripts/
  build-macos-app.sh    # Genera dist/Replacer.app
  generate-icon.swift   # Genera el .icns de distribución
docs/
  native-macos.md       # Guía funcional de la app nativa
  ARCHITECTURE.md       # Diseño técnico y flujo de datos
  DEVELOPMENT.md        # Guía de desarrollo local
  TESTING.md            # Estrategia y comandos de pruebas
  CONFIGURATION.md      # Configuración y artefactos generados
  API.md                # API HTTP de la versión Flask heredada
app.py                  # Versión Flask heredada
static/index.html       # UI web heredada
```

## Inicio rápido

Requisitos:

- macOS 14 o superior.
- Xcode Command Line Tools o Xcode con SwiftPM disponible en terminal.

Ejecuta la app nativa:

```bash
swift run Replacer
```

Para usar la versión web heredada:

```bash
python -m venv .venv
source .venv/bin/activate
pip install flask
python app.py
```

Después abre `http://localhost:5050`.

## Empaquetar la app macOS

```bash
scripts/build-macos-app.sh
```

El bundle se crea en `dist/Replacer.app`. El script genera el icono con `scripts/generate-icon.swift`, compila en release y monta la estructura mínima de bundle macOS.

## Probar

```bash
swift test
```

Los tests usan archivos temporales y no modifican contenido real del repositorio.

## Documentación

- [Guía de la app macOS](docs/native-macos.md)
- [Arquitectura](docs/ARCHITECTURE.md)
- [Desarrollo](docs/DEVELOPMENT.md)
- [Pruebas](docs/TESTING.md)
- [Configuración](docs/CONFIGURATION.md)
- [API heredada Flask](docs/API.md)

## Seguridad

Replacer solo procesa archivos que parecen texto UTF-8 editable. Rechaza archivos con bytes nulos o contenido no decodificable como UTF-8 para evitar corrupción de binarios. Aun así, prueba los reemplazos en una carpeta descartable o con archivos bajo control de versiones.

Antes de modificar un archivo, la app crea una copia junto al original con sufijo `.replacer-backup`. Si ya existe una copia con ese nombre, usa un sufijo incremental.

La versión Flask se conserva como legado. Si se ejecuta con `python app.py`, el endpoint de reemplazo solo permite modificar rutas encontradas previamente por la búsqueda de esa misma sesión, rechaza archivos binarios/no UTF-8 y también crea copias `.replacer-backup`.

## Licencia

Este proyecto incluye licencia MIT en [LICENSE](LICENSE).
