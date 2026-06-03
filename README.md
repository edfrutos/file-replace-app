# Replacer

Replacer es una utilidad local para macOS que busca y reemplaza texto en archivos. La app principal está escrita en SwiftUI y usa un módulo core testeable para localizar archivos, contar coincidencias y escribir reemplazos.

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
app.py                  # Versión Flask heredada
static/index.html       # UI web heredada
```

## Ejecutar en desarrollo

```bash
swift run Replacer
```

## Generar la app macOS

```bash
scripts/build-macos-app.sh
```

El bundle se crea en `dist/Replacer.app`. `dist/`, `.build/` y los iconos generados en `Assets/AppIcon/` están ignorados por Git.

## Probar

```bash
swift test
```

Los tests usan archivos temporales y no modifican contenido real del repositorio.

## Seguridad

Replacer solo procesa archivos que parecen texto UTF-8 editable. Rechaza archivos con bytes nulos o contenido no decodificable como UTF-8 para evitar corrupción de binarios. Aun así, prueba los reemplazos en una carpeta descartable o con archivos bajo control de versiones.

La versión Flask se conserva como legado. Si se ejecuta con `python app.py`, el endpoint de reemplazo solo permite modificar rutas encontradas previamente por la búsqueda de esa misma sesión.

## Versión Flask heredada

```bash
pip install flask
python app.py
```

Después abre `http://localhost:5050`.
