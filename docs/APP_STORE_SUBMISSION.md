<!-- generated-by: hand -->
# Publicar Replacer en el Mac App Store

Esta guía documenta el camino para distribuir Replacer a través del Mac App Store,
en paralelo al DMG ad-hoc que ya se distribuye (ver [RELEASING.md](RELEASING.md)).
**Todos los pasos de este documento requieren Xcode en una Mac**; no se pueden
ejecutar desde este repositorio en un entorno Linux. Lo que sí se preparó desde
el código:

- `Sources/FileReplaceApp/Replacer.entitlements`: entitlements de App Sandbox
  (`com.apple.security.app-sandbox` + `com.apple.security.files.user-selected.read-write`).
  Es el mínimo necesario porque el acceso a carpetas ya pasa por `NSOpenPanel`
  (`ContentView.swift: chooseDirectory()`), que bajo sandbox concede acceso a todo
  el subárbol elegido durante la sesión. No hace falta `bookmarks.app-scope` porque
  la app no persiste la última carpeta entre arranques.
- Dos rutas de UI incompatibles con sandbox quedaron detrás de la bandera de
  compilación `APPSTORE_BUILD` (activa solo en el target nuevo de Xcode, nunca en
  el build SwiftPM/DMG actual):
  - El campo "ruta escrita a mano" (`applyTypedDirectory`) — una ruta tecleada
    nunca tiene permiso de sandbox, así que en el build de App Store ese atajo
    se oculta y solo queda el selector de carpeta.
  - El botón/menú "Buscar actualizaciones…" (`UpdateCenter`) — apunta a las
    releases privadas de GitHub, lo que no tiene sentido ni está permitido como
    mecanismo de actualización en una app de la tienda; se oculta en ese build.

## 0. Decisiones previas (tuyas, no técnicas)

Antes de tocar Xcode, resuelve esto en developer.apple.com / App Store Connect:

1. **Nombre público en la tienda**: comprueba que "Replacer" esté libre como
   nombre de app (los nombres de App Store son únicos). Si no, decide un nombre
   alternativo.
2. **Bundle ID explícito**: regístralo en *Certificates, Identifiers & Profiles*
   (p.ej. `com.edfrutos.Replacer` o `com.edfrutos.replacer-app`). El actual
   `local.replacer.app` del DMG es solo para uso local y no vale para la tienda.
3. **SKU, categoría, precio/disponibilidad, clasificación de edad**.
4. **URL de soporte** y **URL de política de privacidad** (obligatorias aunque la
   app no recoja datos). Ya resueltas con páginas en GitHub:
   - Soporte: `https://github.com/edfrutos/file-replace-app/issues`
   - Marketing: `https://github.com/edfrutos/file-replace-app`
   - Política de privacidad: `https://github.com/edfrutos/file-replace-app/blob/main/PRIVACY.md`
     (contenido en [`PRIVACY.md`](../PRIVACY.md) en la raíz del repo)
5. **Privacy Nutrition Label**: previsiblemente "Data Not Collected" (la app no
   hace red ni analítica; solo lee/escribe archivos que el usuario elige). Revísalo
   tú mismo en el formulario de App Store Connect antes de enviar.
6. **Capturas de pantalla**: tamaños Mac requeridos por App Store Connect en el
   momento de la subida (suele pedir al menos 1280×800 o 2560×1600). Tómalas de
   la app ya corriendo con datos de ejemplo, no de mockups.

## 1. Crear el registro en App Store Connect

En developer.apple.com, registra el App ID del paso 0.2 con capability **App
Sandbox** habilitada. Luego, en App Store Connect, crea el app record (plataforma
macOS) usando ese bundle ID, nombre, SKU e idioma principal.

## 2. Crear el proyecto de Xcode

SwiftPM abierto directamente en Xcode **no** expone la pestaña "Signing &
Capabilities" por target, así que no se puede firmar para distribución ni añadir
App Sandbox sobre el `Package.swift` tal cual. Hace falta un `.xcodeproj` real:

1. Xcode → *File ▸ New ▸ Project ▸ macOS ▸ App*. Nombre `Replacer`, interfaz
   SwiftUI, lenguaje Swift, "Include Tests" desmarcado (ya existen en
   `Tests/FileReplaceCoreTests` dentro del package). Guárdalo en una carpeta
   nueva, por ejemplo `ios/` o `xcode/` dentro del repo, o en un directorio
   hermano — como prefieras, pero no lo guardes dentro de `Sources/`.
2. Borra el `ContentView.swift`/`App.swift` que genera la plantilla.
3. *File ▸ Add Package Dependencies ▸ Add Local…* y selecciona la carpeta raíz
   del repo (donde está `Package.swift`). Añade el producto de librería
   **FileReplaceCore** al target `Replacer` (NO añadas el producto ejecutable
   `Replacer` del Package — ese es el binario SwiftPM para `swift run`/DMG, no se
   usa aquí).
4. Arrastra a ese target, con "Create groups" y sin copiar (para no duplicar
   archivos), estos ficheros existentes:
   - `Sources/FileReplaceApp/FileReplaceApp.swift`
   - `Sources/FileReplaceApp/ContentView.swift`
   - `Sources/FileReplaceApp/UpdateCenter.swift` (opcional: bajo
     `APPSTORE_BUILD` queda inerte; puedes omitirlo del target si prefieres no
     arrastrarlo, ya que ningún call site activo lo necesita en este build)
   - `Sources/FileReplaceApp/Replacer.entitlements`
5. Target `Replacer` ▸ *Signing & Capabilities*:
   - Team: tu cuenta de Developer.
   - Bundle Identifier: el registrado en el paso 0.2.
   - *+ Capability ▸ App Sandbox*. Marca **User Selected File ▸ Read/Write**
     (coincide con el entitlement ya escrito en `Replacer.entitlements`; Xcode
     puede regenerar el archivo de entitlements él mismo al añadir la capability
     — si lo hace, compara que quede igual al que ya está en el repo).
6. Target `Replacer` ▸ *Build Settings*:
   - `macOS Deployment Target`: 14.0 (coincide con `Package.swift`).
   - `Active Compilation Conditions`: añade `APPSTORE_BUILD` (en Release al
     menos; puedes ponerlo también en Debug si vas a probar este target).
   - Info.plist: `CFBundleDisplayName` = Replacer, versión = la de
     `Sources/FileReplaceCore/ReplacerBuildInfo.swift` (mantenla sincronizada a
     mano entre `ReplacerBuildInfo.version` y el "Marketing Version" del target;
     no hay script compartido entre el build SwiftPM y este target de Xcode).
7. Icono: añade un *Asset Catalog* `Assets.xcassets` con un `AppIcon` set y
   genera los tamaños requeridos (16–1024pt @1x/@2x) a partir de
   `Assets/AppIcon/Replacer.icns` o de `Replacer.png`/`Replacer-yellow.png` en la
   raíz del repo. `scripts/generate-icon.swift` dibuja el icono en código; si
   quieres reutilizar ese dibujo para los PNG de cada tamaño en vez de partir de
   un .icns ya existente, dime y preparo una variante del script que exporte el
   set completo de PNGs.
8. Compila (`Cmd+B`) y corre (`Cmd+R`) en Xcode para confirmar que todo enlaza y
   que el flujo de selección de carpeta + búsqueda + reemplazo funciona igual que
   en el bundle DMG. Prueba también casos límite de sandbox: carpetas fuera de
   `~/Documents`/`~/Desktop` (requieren pasar siempre por el panel, nunca por una
   ruta recordada), y confirma que no aparece ni el campo de ruta escrita ni el
   botón de actualizaciones.

## 3. Archivar y subir

1. Selecciona el scheme `Replacer` ▸ destino "Any Mac" ▸ *Product ▸ Archive*.
2. En el Organizer, *Distribute App ▸ App Store Connect ▸ Upload*. Xcode gestiona
   el certificado de distribución y el perfil de aprovisionamiento si "Automatically
   manage signing" está activo.
3. Espera a que App Store Connect termine de procesar el build (recibirás aviso
   por correo o lo verás en la pestaña TestFlight/Build del app record).

## 4. Completar la ficha y enviar a revisión

En App Store Connect, rellena con el build subido: descripción, palabras clave,
capturas (paso 0.6), URL de soporte y privacidad (paso 0.4), Privacy Nutrition
Label (paso 0.5), clasificación de edad, precio. Cuando esté todo, *Add for
Review ▸ Submit*.

## Qué no cambia

El flujo actual (`scripts/build-macos-app.sh`, `scripts/build-dmg.sh`, ver
[RELEASING.md](RELEASING.md)) sigue funcionando igual para la distribución ad-hoc
por DMG: no usa `APPSTORE_BUILD`, así que mantiene el campo de ruta escrita y el
botón de actualizaciones. Son dos builds paralelos del mismo código fuente.
