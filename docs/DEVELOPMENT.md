<!-- generated-by: gsd-doc-writer -->
# Desarrollo

## Entorno Local

Requisitos:

- macOS 14 o superior, según `Package.swift`.
- Swift Package Manager, normalmente instalado con Xcode o Xcode Command Line Tools.
- Python 3 solo si necesitas ejecutar la versión Flask heredada.

Clona el repositorio y entra en el directorio del proyecto:

```bash
git clone git@github.com:edfrutos/file-replace-app.git
cd file-replace-app
```

Ejecuta la app nativa:

```bash
swift run Replacer
```

## Comandos De Desarrollo

| Comando | Descripción |
|---|---|
| `swift run Replacer` | Compila y ejecuta la app macOS nativa en modo desarrollo. |
| `swift test` | Ejecuta los tests del módulo `FileReplaceCore`. |
| `swift build --product Replacer` | Compila el ejecutable nativo sin lanzar la app. |
| `scripts/build-macos-app.sh` | Genera `dist/Replacer.app` en modo release. |
| `python app.py` | Lanza la versión Flask heredada en `http://localhost:5050`. |

Para la versión Flask, usa un entorno virtual si vas a instalar dependencias:

```bash
python -m venv .venv
source .venv/bin/activate
pip install flask
python app.py
```

## Estilo De Código

Swift:

- Mantén la lógica de filesystem en `Sources/FileReplaceCore/`.
- Mantén la UI y el estado de pantalla en `Sources/FileReplaceApp/`.
- Añade tests en `Tests/FileReplaceCoreTests/` cuando cambie el comportamiento de búsqueda, lectura, backups o reemplazo.

Python:

- Usa Python 3 con indentación de 4 espacios.
- Mantén funciones pequeñas y con nombres `snake_case`.
- Las rutas Flask deben devolver diccionarios JSON con campos claros como `error`, `success`, `hits` o `replacements`.

Frontend heredado:

- La UI web vive en un único `static/index.html`.
- Mantén las variables CSS en `:root`.
- Evita dependencias externas nuevas salvo que resuelvan un problema real de mantenimiento.

## Convenciones De Ramas Y PR

No hay una convención de ramas documentada en el repositorio. Para cambios nuevos, usa nombres descriptivos y cortos.

En una PR incluye:

- Resumen de cambios.
- Comandos ejecutados.
- Comprobaciones manuales realizadas.
- Capturas o grabaciones si cambias la UI.

## Artefactos Generados

No edites manualmente estos artefactos salvo que el objetivo sea empaquetar o inspeccionar una release:

- `.build/`
- `dist/`
- `Assets/AppIcon/`
- `__pycache__/`
- `*.replacer-backup`
