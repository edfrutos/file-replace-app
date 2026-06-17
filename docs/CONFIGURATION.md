<!-- generated-by: gsd-doc-writer -->
# Configuración

## Variables De Entorno

El proyecto no define variables de entorno obligatorias. No hay `.env.example`, `.env.sample` ni lecturas de `process.env` porque la app principal es SwiftPM/macOS y la versión Flask heredada se ejecuta localmente sin configuración externa.

| Variable | Requerida | Default | Descripción |
|---|---:|---|---|
| Ninguna | No | N/A | No hay configuración por variables de entorno en el repositorio. |

## Configuración SwiftPM

La configuración principal está en `Package.swift`:

| Ajuste | Valor |
|---|---|
| Nombre del paquete | `Replacer` |
| Plataforma mínima | macOS 14 |
| Ejecutable | `Replacer`, target `FileReplaceApp` |
| Librería | `FileReplaceCore` |
| Tests | `FileReplaceCoreTests` |

## Configuración De Empaquetado

`scripts/build-macos-app.sh` define el empaquetado local:

- App: `Replacer`
- Salida: `dist/Replacer.app`
- Ejecutable: `.build/release/Replacer`
- Icono generado: `Assets/AppIcon/Replacer.icns`
- Bundle identifier: `local.replacer.app`
- Versión mostrada: `1.0.0`
- macOS mínimo del bundle: `14.0`
- Firma: ad-hoc local con `codesign --sign -`

`scripts/generate-icon.swift` genera los PNG del iconset y el `.icns` usando `/usr/bin/iconutil`.

`scripts/build-dmg.sh` crea `dist/Replacer.dmg`. El script reconstruye primero `dist/Replacer.app`, prepara una carpeta temporal con `Replacer.app` y un enlace a `/Applications`, genera el DMG comprimido con `hdiutil` y lo verifica.

## Configuración Flask Heredada

La versión web heredada no usa archivo de configuración. Al ejecutar:

```bash
python app.py
```

Flask arranca en el puerto `5050` con `debug=False`.

## Archivos Ignorados

`.gitignore` excluye artefactos locales y generados:

- `.build/`, `.swiftpm/`, `DerivedData/`
- `dist/`, `*.app/`, `*.dmg`, `*.zip`
- `Assets/AppIcon/`
- `.venv/`, `venv/`, `__pycache__/`
- `PromptBase.md`
- secretos habituales como `.env`, claves privadas y certificados

## Backups De Reemplazo

Al reemplazar, la app crea un backup junto al archivo original con sufijo `.replacer-backup`. Si ya existe, usa sufijos incrementales como `.replacer-backup-1`.

Estos backups son datos del usuario y no forman parte de la configuración del proyecto.
