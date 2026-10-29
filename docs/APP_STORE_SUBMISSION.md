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
   la app ya corriendo con datos de ejemplo, no de mockups. Usa
   `scripts/captura-appstore.sh <nombre>`: deja la ventana en 1440×900 puntos
   y guarda `~/Desktop/appstore-<nombre>.png` a 2880×1800 px (Retina), un
   tamaño 16:10 que App Store Connect acepta. Capturas a mano con ⇧⌘4 salen con
   tamaños arbitrarios (p. ej. 2308×1438) y se rechazan.

## 1. Crear el registro en App Store Connect

En developer.apple.com, registra el App ID del paso 0.2 con capability **App
Sandbox** habilitada. Luego, en App Store Connect, crea el app record (plataforma
macOS) usando ese bundle ID, nombre, SKU e idioma principal.

## 2. Crear el proyecto de Xcode

SwiftPM abierto directamente en Xcode **no** expone la pestaña "Signing &
Capabilities" por target, así que no se puede firmar para distribución ni añadir
App Sandbox sobre el `Package.swift` tal cual. Hace falta un `.xcodeproj` real.
Asumiendo que ya tienes `Replacer.provisionprofile`, `app.cer` e `installer.cer`
generados en el portal de Developer (firma manual, no automática):

### 2.1 Instalar el certificado y el perfil antes de abrir Xcode

1. Doble clic en `app.cer` (y en `installer.cer` si vas a subir también un
   instalador) → se añaden a Keychain Access. Esto solo firma correctamente si
   el par de claves privadas generado junto con el CSR original también está en
   tu llavero — si Keychain Access no muestra una flecha desplegable junto al
   certificado con una clave privada dentro, el certificado no servirá para
   firmar y hay que regenerarlo desde un CSR creado en este mismo Mac.
2. Doble clic en `Replacer.provisionprofile` → macOS lo instala en
   `~/Library/MobileDevice/Provisioning Profiles/`. Xcode lo detectará luego
   automáticamente en el selector de perfiles.

### 2.2 Asistente "New Project"

1. Abre Xcode. En la pantalla de bienvenida, botón **Create New Project...**
   (o, con Xcode ya abierto, `File ▸ New ▸ Project…`, `⇧⌘N`).
2. Pestaña superior **macOS** (no iOS). En la sección "Application", selecciona
   la plantilla **App** (el icono con una ventana). Clic **Next**.
3. Formulario de opciones del proyecto:
   - **Product Name**: `Replacer`
   - **Team**: tu cuenta de Developer (si no aparece, añádela antes en
     `Xcode ▸ Settings… ▸ Accounts ▸ +`)
   - **Organization Identifier**: el prefijo reverse-DNS que ya usaste al
     registrar el App ID en el portal (por ejemplo `com.edfrutos`). Junto con
     el Product Name, Xcode compondrá el Bundle Identifier
     `com.edfrutos.Replacer` — debe coincidir exactamente con el App ID ligado
     a tu `Replacer.provisionprofile`; si no coincide, lo corriges luego en el
     paso 2.4.
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - **Storage**: `None`
   - **Include Tests**: desmarcado (ya existen en `Tests/FileReplaceCoreTests`
     dentro del paquete SwiftPM)
   Clic **Next**.
4. Diálogo de guardado: navega a la raíz del repo (`file-replace-app/`) y
   guarda ahí (creará una carpeta `Replacer/` con el `.xcodeproj` dentro — no
   lo metas en `Sources/`). Si aparece la casilla **Create Git repository on my
   Mac**, desmárcala (el repo ya existe). Clic **Create**.

### 2.3 Limpiar la plantilla y enganchar el código existente

1. En el Project Navigator (panel izquierdo, icono de carpeta), dentro del
   grupo amarillo `Replacer`, verás `ReplacerApp.swift` y `ContentView.swift`
   generados por la plantilla. Click derecho sobre cada uno ▸ **Delete** ▸
   **Move to Trash** (los sustituimos por el código real de la app).
2. Añadir `FileReplaceCore` como dependencia local: selecciona el proyecto
   (icono azul de Xcode, arriba del todo en el Navigator) ▸ en el editor
   central, con el proyecto `Replacer` (no el target) seleccionado en la
   columna izquierda, abre la pestaña superior **Package Dependencies** ▸ clic
   en el botón **+** debajo de la lista ▸ en el diálogo, botón
   **Add Local…** (abajo a la izquierda) ▸ navega hasta la raíz del repo
   (donde está `Package.swift`) y selecciona esa carpeta ▸ **Add Package**.
3. Aparece un diálogo "Choose Package Products": marca solo **FileReplaceCore**
   con "Add to Target" = `Replacer` (NO marques el producto ejecutable
   `Replacer` del propio Package — ese es el binario de `swift run`/DMG, no se
   usa aquí). Clic **Add Package**.
4. En Finder, abre la carpeta del repo y arrastra estos archivos desde
   `Sources/FileReplaceApp/` hasta el grupo `Replacer` en el Project Navigator
   de Xcode:
   - `FileReplaceApp.swift`
   - `ContentView.swift`
   - `Replacer.entitlements`
   - (opcional) `UpdateCenter.swift` — bajo `APPSTORE_BUILD` queda inerte, así
     que puedes omitirlo si prefieres no arrastrarlo.
   En el diálogo que aparece al soltar: **desmarca** "Copy items if needed"
   (así Xcode referencia los ficheros originales en vez de duplicarlos),
   "Added folders" = **Create groups**, y en "Add to targets" marca `Replacer`.
   Clic **Finish**.

### 2.4 Firma y App Sandbox

Selecciona el target `Replacer` (no el proyecto) en la columna izquierda del
editor central, pestaña **Signing & Capabilities**:

1. **Team**: tu cuenta de Developer.
2. **Bundle Identifier**: escribe exactamente el App ID registrado (el ligado
   a tu provisioning profile), sobrescribiendo el que generó el asistente si
   no coincide.
3. Desmarca **Automatically manage signing** (ya tienes perfil y certificados
   generados manualmente).
4. **Provisioning Profile**: despliega el selector ▸ debería aparecer
   `Replacer.provisionprofile` ya instalado (paso 2.1); si no aparece, usa la
   opción **Import Profile…** del mismo desplegable y selecciona el archivo.
5. **Signing Certificate**: debería autoseleccionarse al elegir el perfil, ya
   que ambos están ligados al mismo App ID. Si Xcode marca error de "no
   matching signing identity", vuelve a Keychain Access y confirma que el
   certificado tiene su clave privada asociada (paso 2.1).
6. Clic en **+ Capability** (arriba a la izquierda de esta pestaña) ▸
   doble clic en **App Sandbox** para añadirlo.
7. En el recuadro "App Sandbox" que aparece, en la sección **File Access**,
   marca la fila **User Selected File** y pon su desplegable en **Read/Write**.
8. Comprueba el archivo de entitlements resultante: ve a la pestaña
   **Build Settings** del target, busca `Code Signing Entitlements` y confirma
   que apunta a `Sources/FileReplaceApp/Replacer.entitlements` (el que ya está
   en el repo). Si Xcode creó uno nuevo en la carpeta del proyecto al añadir la
   capability, ábrelo como texto y compáralo: debe tener exactamente
   `com.apple.security.app-sandbox` y
   `com.apple.security.files.user-selected.read-write` a `true`; si coincide,
   puedes quedarte con cualquiera de los dos y borrar el duplicado.

### 2.5 Ajustes de build

Sigue en el target `Replacer`:

1. Pestaña **Build Settings** ▸ busca `macOS Deployment Target` ▸ ponlo a
   `14.0` (coincide con `Package.swift`).
2. Misma pestaña ▸ busca `Active Compilation Conditions` ▸ doble clic en el
   valor de la fila `Release` (y de `Debug` si vas a probar este target antes
   de archivar) ▸ añade `APPSTORE_BUILD`.
3. Pestaña **General** ▸ sección "Identity":
   - **Display Name**: `Replacer`
   - **Version** (Marketing Version / `CFBundleShortVersionString`): `1.3.1` (la 1.3.0 se envió con el build 3),
     igual que `Sources/FileReplaceCore/ReplacerBuildInfo.swift`. No hay script
     compartido entre el build SwiftPM y este target de Xcode, así que toca
     mantenerlo sincronizado a mano en cada release.
   - **Build** (`CFBundleVersion`, `CURRENT_PROJECT_VERSION` en el proyecto): un
     entero, con numeración independiente del `BUNDLE_VERSION` del DMG. App Store
     Connect rechaza un build repetido, así que súbelo en cada envío. El último
     subido es el `3`; el proyecto ya está en `4` para el siguiente. Si en
     *Distribute App* dejas que Xcode gestione el número de build, lo sube él solo
     en el archive pero no en el repo: actualiza `project.pbxproj` después para
     que coincidan.

### 2.6 Icono

La fuente del icono es `Assets/AppIcon/Replacer-master.png`: el icono de
cuero a 1024 px, ya ajustado a la rejilla de macOS (placa de 824 px centrada,
esquinas transparentes y sombra suave). `scripts/generate-icon.swift` lo
escala a todos los tamaños y escribe a la vez el `.iconset`/`.icns` del build
DMG y los PNG de `Replacer/Replacer/Assets.xcassets/AppIcon.appiconset/`.

Para cambiar el icono, sustituye el master por otro PNG cuadrado de 1024 px
con el mismo margen y, en tu Mac, desde la raíz del repo, ejecuta
`swift scripts/generate-icon.swift` (necesita AppKit: no funciona en Linux).
No hace falta arrastrar nada en Xcode: el asset catalog ya referencia esos
archivos. El icono azul dibujado en código (builds 2 y 3) está en el
historial de git, commit `2cdbeb8`.

### 2.7 Compilar y probar

Antes de nada, en el selector de scheme (barra superior de Xcode) elige
**Replacer App Store**, no **Replacer**. El paquete SwiftPM tiene un producto
ejecutable que también se llama `Replacer` y Xcode le crea un scheme con ese
nombre: si lo ejecutas, arranca el binario de `swift run`/DMG, compilado sin
`APPSTORE_BUILD` (verás el campo de ruta con «Usar» y el botón
«Actualizaciones»). El scheme compartido
`Replacer/Replacer.xcodeproj/xcshareddata/xcschemes/Replacer App Store.xcscheme`
apunta al target de la app.

`Cmd+B` para compilar y `Cmd+R` para ejecutar. Verifica que:

- La app arranca y el flujo de selección de carpeta + búsqueda + reemplazo
  funciona igual que en el bundle DMG.
- **No** aparece el campo de ruta escrita a mano ni el botón "Actualizaciones"
  (confirma que `APPSTORE_BUILD` se aplicó).
- Probar sandbox real: elige una carpeta fuera de `~/Documents`/`~/Desktop`
  (p. ej. en `~/Developer`) únicamente a través del panel nativo — nunca
  funcionará una ruta recordada de sesiones anteriores, porque el sandbox no
  persiste permisos entre lanzamientos en esta versión.

## 3. Archivar y subir

1. En la barra superior de Xcode, junto al selector de scheme, cambia el
   destino de ejecución a **My Mac** (no un simulador).
2. `Product ▸ Archive` (menú superior). Xcode compila en Release y, al
   terminar, abre automáticamente la ventana **Organizer**.
3. En Organizer, con el archive recién creado seleccionado, botón
   **Distribute App** ▸ **App Store Connect** ▸ **Upload** ▸ **Next**.
4. En la pantalla de opciones de firma, como tienes signing manual, elige
   **Manually manage signing** ▸ selecciona el mismo perfil/certificado del
   paso 2.4 ▸ **Next** ▸ **Upload**.
5. Espera a que App Store Connect termine de procesar el build (aviso por
   correo, o visible en la pestaña **TestFlight**/**Compilación** del app
   record — puede tardar de varios minutos a más de una hora).

## 4. Completar la ficha y enviar a revisión

En App Store Connect, rellena con el build subido: descripción, palabras clave
(textos listos en [APP_STORE_LISTING.md](APP_STORE_LISTING.md)),
notas para el revisor ([APP_REVIEW_NOTES.md](APP_REVIEW_NOTES.md)),
capturas (paso 0.6), URL de soporte y privacidad (paso 0.4), Privacy Nutrition
Label (paso 0.5), clasificación de edad, precio. Cuando esté todo, *Add for
Review ▸ Submit*.

## Qué no cambia

El flujo actual (`scripts/build-macos-app.sh`, `scripts/build-dmg.sh`, ver
[RELEASING.md](RELEASING.md)) sigue funcionando igual para la distribución ad-hoc
por DMG: no usa `APPSTORE_BUILD`, así que mantiene el campo de ruta escrita y el
botón de actualizaciones. Son dos builds paralelos del mismo código fuente.
