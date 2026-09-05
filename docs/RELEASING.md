<!-- generated-by: hand -->
# Publicar una release

Pasos para cortar y empaquetar una versión de Replacer. Todo se ejecuta en macOS con
Xcode Command Line Tools instaladas.

## 1. Subir la versión

Edita la constante en un único sitio:

```swift
// Sources/FileReplaceCore/ReplacerBuildInfo.swift
public static let version = "1.2.0"
```

Si cambias el *build* del bundle, ajústalo en `scripts/build-macos-app.sh`
(`BUNDLE_VERSION`). Actualiza `CHANGELOG.md` y la sección de versión de `README.md`.

## 2. Verificar

```bash
swift test                       # 14 tests en verde
swift build --product Replacer   # la app SwiftUI completa compila
python3 -m py_compile app.py      # la versión Flask heredada sigue compilando
```

Luego la pasada manual de [`TESTING_HUMANO.md`](../TESTING_HUMANO.md), usando el bundle
(`script/build_and_run.sh`), no `swift run`.

## 3. Empaquetar

```bash
scripts/build-macos-app.sh       # genera dist/Replacer.app (release, firma ad-hoc)
scripts/build-dmg.sh             # genera dist/Replacer-<versión>.dmg + lo verifica
```

`build-dmg.sh` reconstruye el `.app` primero, así que basta con ejecutar el segundo.

Qué hacen los scripts:

- `generate-icon.swift` dibuja `Assets/AppIcon/Replacer.icns`.
- `build-macos-app.sh` compila en release, monta `Contents/{MacOS,Resources,Info.plist}`,
  lee `APP_VERSION` de `ReplacerBuildInfo.swift`, fija `CFBundleShortVersionString` y
  `CFBundleVersion`, y firma con `codesign --force --deep --sign -` (ad-hoc).
- `build-dmg.sh` prepara una carpeta con `Replacer.app` + enlace a `/Applications`,
  crea el DMG UDZO con `hdiutil` y hace `hdiutil verify`.

La app **no** depende de `Bundle.module`: la versión es una constante Swift y el icono de
cabecera se dibuja en código, así que el bundle mínimo que montan los scripts es suficiente.

## 4. Comprobaciones del artefacto

```bash
codesign --verify --deep --strict --verbose=2 dist/Replacer.app
spctl --assess --type execute --verbose dist/Replacer.app   # fallará: no notarizado
hdiutil verify dist/Replacer-<versión>.dmg
shasum -a 256 dist/Replacer-<versión>.dmg
```

- La firma ad-hoc verifica localmente pero **Gatekeeper la rechaza** en otros equipos.
  El destinatario debe abrir con clic derecho > `Abrir` y, si hace falta, autorizarla en
  Ajustes del Sistema > Privacidad y seguridad.
- Comparte la suma SHA‑256 por un canal aparte para que se pueda verificar el DMG.
- Distribución pública sin advertencias = firma Developer ID + notarización (no cubierto aquí).

## 5. Tag y GitHub Release

```bash
git tag -a v<versión> -m "Replacer v<versión>"
git push origin main
git push origin v<versión>
gh release create v<versión> dist/Replacer-<versión>.dmg \
  --title "Replacer v<versión>" \
  --notes-file <(sed -n '/^## \[<versión>\]/,/^## \[/p' CHANGELOG.md | sed '$d')
```

Marca la release como **prerelease** o **limited** según proceda; esta distribución es privada.

## 6. Documentar

- `README.md`: actualizar el enlace y el número de la versión estable.
- `docs/CONFIGURATION.md`: versión mostrada y build.
- Marcar en `TESTING_HUMANO.md` la fecha de la última pasada manual completa.
