# Replacer

Replacer es una utilidad local para macOS que busca, revisa y reemplaza texto en archivos UTF-8 con confirmación explícita y copias de seguridad automáticas. La app permite revisar manualmente las releases disponibles en GitHub.

La app principal está escrita en SwiftUI y usa un módulo core testeable para localizar archivos, contar coincidencias, rechazar contenido no editable y escribir reemplazos. La versión Flask se conserva como interfaz web heredada.

## Versión publicada

La versión estable actual es [Replacer 1.2.0](https://github.com/edfrutos/file-replace-app/releases/tag/v1.2.0), publicada como DMG para distribución limitada en equipos Apple silicon. El registro de cambios está en [CHANGELOG.md](CHANGELOG.md).

El artefacto está firmado de forma ad-hoc y no está notarizado por Apple. Es válido para pruebas y distribución local controlada, pero Gatekeeper lo rechaza en su validación automática al descargarlo en otros equipos. El destinatario debe verificar el origen y usar `Abrir` desde el menú contextual; macOS puede exigir además confirmar `Abrir igualmente` en Privacidad y seguridad. La distribución pública sin esas advertencias requiere una firma Developer ID y notarización.

## Estructura

```text
Package.swift
Sources/
  FileReplaceApp/       # App macOS SwiftUI
  FileReplaceCore/      # Lógica de búsqueda y reemplazo + ReplacerBuildInfo (versión)
Tests/
  FileReplaceCoreTests/ # Tests unitarios con directorios temporales
scripts/
  build-macos-app.sh    # Genera dist/Replacer.app
  build-dmg.sh          # Genera dist/Replacer-<versión>.dmg
  generate-icon.swift   # Genera el .icns de distribución
docs/
  native-macos.md       # Guía funcional de la app nativa
  ARCHITECTURE.md       # Diseño técnico y flujo de datos
  DEVELOPMENT.md        # Guía de desarrollo local
  TESTING.md            # Estrategia y comandos de pruebas
  CONFIGURATION.md      # Configuración y artefactos generados
  API.md                # API HTTP de la versión Flask heredada
TESTING_HUMANO.md       # Checklist de validación manual completa
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

Para compilarla como bundle macOS, cerrar cualquier instancia anterior y abrirla:

```bash
script/build_and_run.sh
```

Usa `script/build_and_run.sh --verify` para comprobar además que el proceso arrancó. En Codex, la acción `Run` ejecuta el mismo flujo.

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

El bundle se crea en `dist/Replacer.app`. El script genera el icono con `scripts/generate-icon.swift`, compila en release, monta la estructura mínima de bundle macOS y aplica firma ad-hoc local.

Para crear un DMG local:

```bash
scripts/build-dmg.sh
```

El DMG se crea como `dist/Replacer-<versión>.dmg` e incluye `Replacer.app` y un acceso directo a `/Applications`.

Para distribución limitada, comparte también la suma SHA-256 por un canal independiente para que el destinatario pueda verificar el archivo antes de abrirlo.

La versión se define en `Sources/FileReplaceCore/ReplacerBuildInfo.swift` (`ReplacerBuildInfo.version`). Actualiza esa constante antes de empaquetar una nueva release; los scripts la leen para `CFBundleShortVersionString` y el nombre del DMG.

## Probar

```bash
swift test
```

Los tests usan archivos temporales y no modifican contenido real del repositorio.

## Documentación

- [Guía de la app macOS](docs/native-macos.md)
- [Arquitectura](docs/ARCHITECTURE.md)
- [Propuesta: localizar en Finder y previsualizar contenido](docs/FEATURE-locate-finder-preview.md)
- [Desarrollo](docs/DEVELOPMENT.md)
- [Pruebas](docs/TESTING.md)
- [Testing humano](TESTING_HUMANO.md)
- [Configuración](docs/CONFIGURATION.md)
- [Publicar una release](docs/RELEASING.md)
- [Cambios](CHANGELOG.md)
- [API heredada Flask](docs/API.md)

## Seguridad

Replacer solo procesa archivos que parecen texto UTF-8 editable. Rechaza archivos con bytes nulos o contenido no decodificable como UTF-8 para evitar corrupción de binarios. Aun así, prueba los reemplazos en una carpeta descartable o con archivos bajo control de versiones.

Antes de modificar un archivo, la app crea una copia junto al original con sufijo `.replacer-backup`. Si ya existe una copia con ese nombre, usa un sufijo incremental.

La versión Flask se conserva como legado. Si se ejecuta con `python app.py`, el endpoint de reemplazo solo permite modificar rutas encontradas previamente por la búsqueda de esa misma sesión, rechaza archivos binarios/no UTF-8 y también crea copias `.replacer-backup`.

## Licencia

Este proyecto incluye licencia MIT en [LICENSE](LICENSE).
