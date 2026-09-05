# Propuesta: localizar en Finder y previsualizar contenido desde los resultados

Estado: **implementado** (ver `## [Sin publicar]` en [`CHANGELOG.md`](../CHANGELOG.md)). Este
documento fue la especificación previa a la implementación y se conserva como registro de diseño
y de las decisiones tomadas (por ejemplo, la reestructuración de `HitRow` del punto 5.3). El
comportamiento actual de la app está descrito en [`docs/native-macos.md`](native-macos.md) y
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md); ante cualquier discrepancia, esos documentos son la
fuente de verdad, no este.

## 1. Objetivo

Hoy, en `Sources/FileReplaceApp/ContentView.swift`, cada resultado (`HitRow`) muestra la ruta
relativa, la ruta completa y una vista previa corta (`hit.preview`, ~180 caracteres alrededor de
la primera coincidencia, generada por `FileReplaceService.search`). No hay forma de:

- Abrir Finder con el archivo ya seleccionado.
- Ver el contenido completo del archivo (todas las coincidencias, no solo la primera) sin abrirlo
  en otra aplicación.

Se añaden dos acciones por resultado: **Mostrar en Finder** y **Ver contenido**.

## 2. Alcance

Incluido:

- Botón/acción por fila de resultado que revela el archivo en Finder (`NSWorkspace`).
- Botón/acción por fila de resultado que abre una vista de solo lectura con el contenido íntegro
  del archivo y resalta las coincidencias de `searchText`.
- Manejo de errores cuando el archivo ha cambiado, se ha movido o se ha borrado entre la búsqueda
  y la acción del usuario.
- Tests unitarios del nuevo método de lectura en `FileReplaceCore`.
- Ampliación del checklist de `TESTING_HUMANO.md`.

Fuera de alcance (posible trabajo futuro, no abordar en esta iteración):

- Edición inline del contenido en la vista previa (la app ya edita mediante el flujo de
  reemplazo existente; la previsualización es de solo lectura).
- Resaltado de sintaxis por tipo de archivo.
- "Abrir con…" para lanzar un editor externo.
- Vista de diff entre el contenido actual y el resultado tras un reemplazo.

## 3. Diseño funcional (UX)

En `HitRow`, junto a la cápsula `"N coincidencia(s)"`, se añaden dos botones con icono y texto de
ayuda (`.help`):

- **Mostrar en Finder** — `systemImage: "folder"`. Al pulsarlo, si el archivo sigue existiendo,
  Finder pasa a primer plano con el archivo seleccionado en su carpeta contenedora. Si ya no
  existe, no se abre Finder y el `statusMessage` de la cabecera informa del problema (por ejemplo,
  "No se pudo localizar en Finder: el archivo ya no existe en `<ruta>`.").
- **Ver contenido** — `systemImage: "doc.text.magnifyingglass"`. Al pulsarlo se abre una hoja
  (`.sheet`) con:
  - Cabecera: ruta relativa, ruta completa (seleccionable) y número de coincidencias.
  - Cuerpo: contenido completo del archivo en un visor de solo lectura, monoespaciado, con cada
    aparición de `searchText` resaltada (fondo amarillo, coherente con `ReplacerTheme.amber`).
  - Pie: botón **Mostrar en Finder** (mismo comportamiento que en la fila) y botón **Cerrar**.
  - Si la lectura falla (archivo borrado, ya no es UTF-8, supera el tamaño máximo), la hoja
    muestra un mensaje de error en vez del contenido, reutilizando `FileReplaceError.errorDescription`.

Importante: estos dos botones deben poder pulsarse sin alternar la selección del resultado. Hoy
toda la fila es un único `Button` que llama a `onToggle`. Ver la sección 5.3 para el cambio de
estructura necesario.

## 4. Diseño técnico — `FileReplaceCore`

### 4.1 Nuevo método público en `FileReplaceService`

`readTextFile(_:maxBytes:)` ya existe como método **privado** y hace exactamente lo que necesita
la previsualización: valida tamaño, rechaza bytes nulos y contenido no UTF-8. Se expone mediante
un método público que opera sobre una URL (no sobre un `SearchHit`, para no acoplar la firma a un
resultado de búsqueda concreto):

```swift
/// Lee el contenido completo de un archivo de texto para previsualizarlo.
/// Reutiliza las mismas validaciones que `search` (UTF-8 estricto, tamaño máximo).
public func readFullContent(
    at fileURL: URL,
    maxBytes: Int = FileReplaceService.defaultMaxFileSizeBytes
) throws -> String {
    try readTextFile(fileURL, maxBytes: maxBytes)
}
```

No se introduce un límite de tamaño distinto al de búsqueda: si un archivo ya se excluyó de los
resultados por tamaño, tampoco tendría un `SearchHit` desde el que pedir la previsualización, así
que reutilizar `defaultMaxFileSizeBytes` mantiene una única fuente de verdad. Si en el futuro se
detecta que los usuarios quieren previsualizar archivos más grandes que los que se buscan, se
puede añadir un límite específico entonces, no antes.

Errores que puede lanzar (ya existen en `FileReplaceError`, no se añaden casos nuevos):

- `.unsupportedFileType` — el archivo ya no es UTF-8 editable (se modificó fuera de Replacer).
- `.fileTooLarge` — el archivo creció por encima del límite desde la búsqueda.
- `.readFailed` — no se pudo leer (borrado, permisos, volumen desmontado).

### 4.2 Localizar coincidencias para resaltar

Para resaltar todas las apariciones en la vista, no solo la primera (que es lo único que calcula
`preview(around:context:)`), se necesita la lista de rangos. Añadir una función de utilidad junto
a `nonOverlappingCount(of:)` en la extensión privada de `String` del mismo archivo:

```swift
private extension String {
    func ranges(of needle: String) -> [Range<Index>] {
        guard !needle.isEmpty else { return [] }
        var result: [Range<Index>] = []
        var searchStart = startIndex
        while let range = range(of: needle, range: searchStart..<endIndex) {
            result.append(range)
            searchStart = range.upperBound
        }
        return result
    }
}
```

Esta función puede vivir en `FileReplaceCore` (junto a `nonOverlappingCount`) o directamente en la
capa de UI si se prefiere no ampliar la superficie pública del core solo para resaltado visual. Se
recomienda mantenerla **privada al core y sin exponerla**: la UI puede recalcular los rangos sobre
el `String` que recibe de `readFullContent`, usando la misma lógica de `range(of:range:)`
directamente en `FileReplaceApp` (ver 5.2). Así `FileReplaceCore` no crece con una API pensada solo
para presentación.

### 4.3 Tests (`Tests/FileReplaceCoreTests/FileReplaceCoreTests.swift`)

Añadir junto a los tests existentes de `FileReplaceService`:

- `readFullContent` devuelve el contenido íntegro de un archivo de fixture (no solo el entorno de
  la primera coincidencia como hace `preview`).
- `readFullContent` lanza `.readFailed` si el archivo se borra tras crearlo.
- `readFullContent` lanza `.unsupportedFileType` sobre un archivo con bytes nulos.
- `readFullContent` lanza `.fileTooLarge` cuando se pasa un `maxBytes` menor que el tamaño real
  (reutilizar el patrón ya usado para el test equivalente de `search`).

## 5. Diseño técnico — `FileReplaceApp`

### 5.1 Revelar en Finder

Nueva función en `FileReplaceViewModel` (`ContentView.swift`):

```swift
func revealInFinder(_ hit: SearchHit) {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: hit.fileURL.path, isDirectory: &isDirectory) else {
        statusMessage = "No se pudo localizar en Finder: el archivo ya no existe en \(hit.fileURL.path)."
        return
    }
    NSWorkspace.shared.activateFileViewerSelecting([hit.fileURL])
}
```

`activateFileViewerSelecting` ya trae Finder a primer plano y selecciona el archivo; no requiere
permisos adicionales porque el usuario ya concedió acceso a la carpeta al elegirla o escribir su
ruta. No se necesita sandboxing especial: la app no está sandboxed (firma ad-hoc local, ver
`docs/CONFIGURATION.md`).

### 5.2 Ver contenido

Nuevo estado en `FileReplaceViewModel`:

```swift
@Published var previewHit: SearchHit?
@Published var previewContent: String?
@Published var previewError: String?
@Published var isLoadingPreview = false
```

Nueva función, siguiendo el mismo patrón asíncrono que `search()` y `replaceSelected()`
(`Task.detached` para no bloquear la UI):

```swift
func openPreview(for hit: SearchHit) {
    previewHit = hit
    previewContent = nil
    previewError = nil
    isLoadingPreview = true

    let text = searchText
    let service = self.service

    Task {
        do {
            let content = try await Task.detached(priority: .userInitiated) {
                try service.readFullContent(at: hit.fileURL)
            }.value
            previewContent = content
        } catch {
            previewError = error.localizedDescription
        }
        isLoadingPreview = false
    }
}

func closePreview() {
    previewHit = nil
    previewContent = nil
    previewError = nil
}
```

`text` (el `searchText` capturado al abrir la hoja) se usa para resaltar en la vista, no para
volver a buscar; si el usuario cambia el campo de búsqueda mientras la hoja está abierta, el
resaltado debe seguir usando el texto con el que se generó ese resultado, así que conviene
capturarlo en el momento de abrir la hoja en vez de leer `viewModel.searchText` en la vista.

`ContentView` añade la hoja al `detailPane` (o a la vista raíz, para que cubra toda la ventana):

```swift
.sheet(item: $viewModel.previewHit) { hit in
    FileContentPreviewView(
        hit: hit,
        content: viewModel.previewContent,
        errorMessage: viewModel.previewError,
        isLoading: viewModel.isLoadingPreview,
        highlightText: /* searchText capturado al abrir */,
        onRevealInFinder: { viewModel.revealInFinder(hit) },
        onClose: { viewModel.closePreview() }
    )
}
```

`SearchHit` ya es `Identifiable` (`id` = ruta absoluta), así que `.sheet(item:)` funciona sin
envoltorios adicionales.

`FileContentPreviewView` (nueva vista, en `ContentView.swift` o en un archivo nuevo
`FileContentPreviewView.swift` si el archivo actual crece demasiado):

- Cabecera con ruta relativa (`.headline`), ruta completa (`.caption`, `.textSelection(.enabled)`)
  y contador de coincidencias.
- Cuerpo:
  - Si `isLoading`, un `ProgressView` centrado.
  - Si `errorMessage` no es `nil`, un mensaje de error con icono de advertencia (mismo lenguaje
    visual que otros errores: `ReplacerTheme.amber` o similar).
  - Si `content` no es `nil`, un visor de texto de solo lectura con resaltado. Ver 5.2.1.
- Pie con `Button("Mostrar en Finder")` y `Button("Cerrar")`.

#### 5.2.1 Visor de solo lectura con resaltado

Reutilizar el patrón de `PlainNSTextEditor` pero en modo lectura y con resaltado. Opciones,
de más a menos recomendable:

1. **`NSTextView` no editable con `NSAttributedString`** (recomendado). Nueva vista
   `NSViewRepresentable` (`ReadOnlyHighlightedTextView`) que recibe `content: String` y
   `highlightText: String`, construye un `NSAttributedString` con
   `.backgroundColor: NSColor` aplicado a cada rango encontrado con `range(of:range:)` (mismo
   bucle que `nonOverlappingCount`, pero sobre `NSString`/`NSRange` porque `NSTextStorage` trabaja
   con `NSRange`), fuente `.monospacedSystemFont`, `isEditable = false`, `isSelectable = true`
   (para permitir copiar texto). Ventaja: reutiliza toda la infraestructura de `NSTextView` que ya
   usa el proyecto (misma familia que `PlainNSTextEditor`), rinde bien con archivos de hasta 5 MB
   (el límite ya existente) y no depende de recorrer todo el árbol de `Text` de SwiftUI coincidencia
   a coincidencia.
2. Alternativa más simple pero menos eficiente: partir el contenido en fragmentos con
   `Text` + `.foregroundStyle`/`.background` por fragmento dentro de un `Text` concatenado
   (`Text(a) + Text(b).background(...) + ...`). Viable solo si el archivo es corto; con archivos
   de varios cientos de KB, el número de vistas `Text` puede degradar el rendimiento. No
   recomendado como primera implementación.

Se recomienda la opción 1. Si el número de coincidencias es muy alto (archivos con miles de
apariciones), limitar el resaltado a las primeras N (por ejemplo 500) y mostrar una nota
("Resaltando las primeras 500 de N coincidencias") para no penalizar el render.

### 5.3 Reestructurar `HitRow` para botones anidados

Hoy `HitRow.body` envuelve toda la fila en un único `Button(action: onToggle)`. SwiftUI permite
controles interactivos anidados dentro de un `Button` si tienen su propio `buttonStyle` y no
comparten el mismo `contentShape`, pero es frágil (el toque puede propagarse al `Button` externo
según la plataforma/versión). Cambio recomendado:

- Quitar el `Button` que envuelve toda la fila.
- Mantener el fondo, sombra y borde de la fila en un `VStack`/`HStack` normal (no interactivo).
- Envolver **solo** el área de selección (icono de check + ruta relativa + ruta completa +
  preview) en un `Button(action: onToggle)` con `.buttonStyle(.plain)`, igual que ahora pero
  acotado a esa subregión.
- Añadir los dos botones nuevos (Finder, Ver contenido) en un `HStack` independiente, alineado a
  la cápsula de coincidencias, cada uno con su propio `Button` y `.buttonStyle(.borderless)` o
  `.buttonStyle(.plain)` con icono.

Esto evita ambigüedad de gestos y dej a cada botón con su propio target de toque, sin heurísticas
de macOS sobre qué botón "gana" el toque.

## 6. Errores y casos límite

| Caso | Mostrar en Finder | Ver contenido |
|---|---|---|
| Archivo sigue igual que en la búsqueda | Selecciona el archivo en Finder | Muestra el contenido completo con resaltado |
| Archivo borrado desde la búsqueda | `statusMessage` de error, no abre Finder | `previewError` con el mensaje de `.readFailed` |
| Archivo movido/renombrado desde la búsqueda | Igual que borrado (la ruta ya no existe) | Igual que borrado |
| Archivo modificado y ya no es UTF-8 | Sin cambios (Finder no valida contenido) | `previewError` con `.unsupportedFileType` |
| Archivo creció por encima de 5 MB | Sin cambios | `previewError` con `.fileTooLarge` |
| Volumen externo desmontado | `statusMessage` de error | `previewError` con `.readFailed` |
| Backup `.replacer-backup` | No aplica: nunca aparece como `SearchHit` (excluido en `findFiles`) | No aplica |

Ninguno de estos flujos debe crear, mover ni modificar archivos: ambas acciones son de solo
lectura sobre el filesystem.

## 7. Cambios de archivos (resumen)

- `Sources/FileReplaceCore/FileReplaceService.swift` — nuevo método público `readFullContent(at:maxBytes:)`.
- `Tests/FileReplaceCoreTests/FileReplaceCoreTests.swift` — tests del punto 4.3.
- `Sources/FileReplaceApp/ContentView.swift`:
  - `FileReplaceViewModel`: estado y funciones de 5.1 y 5.2.
  - `HitRow`: reestructuración de 5.3 y los dos botones nuevos.
  - Nueva vista `FileContentPreviewView` (y `ReadOnlyHighlightedTextView` como `NSViewRepresentable`).
  - `ContentView.detailPane` (o vista raíz): `.sheet(item: $viewModel.previewHit)`.
- `TESTING_HUMANO.md` — nuevos pasos de validación manual (punto 8).
- `docs/native-macos.md` — ampliar "Flujo de uso" con los dos pasos nuevos una vez implementado.
- `docs/ARCHITECTURE.md` — añadir `readFullContent` a la tabla de "Abstracciones Clave" una vez implementado.
- `CHANGELOG.md` — entrada en la próxima versión (`### Añadido`) una vez implementado.

Los tres últimos puntos se actualizan **al implementar**, no en esta propuesta, para que la
documentación de arquitectura y el changelog sigan describiendo únicamente el comportamiento real
de la app.

## 8. Validación manual a incorporar en `TESTING_HUMANO.md`

Añadir una sección nueva ("Localizar en Finder y ver contenido") con pasos como:

1. Buscar una cadena que aparezca en varios archivos, incluidos algunos en subdirectorios
   (búsqueda recursiva).
2. Pulsar **Mostrar en Finder** sobre un resultado de primer nivel y sobre uno anidado: Finder
   debe pasar a primer plano con el archivo correcto seleccionado en ambos casos.
3. Pulsar **Ver contenido** sobre un resultado con varias coincidencias: la hoja debe mostrar el
   archivo completo con todas las apariciones resaltadas, no solo la primera.
4. Con la hoja abierta, comprobar que **Mostrar en Finder** desde dentro de la hoja funciona igual
   que desde la fila.
5. Cerrar la hoja y confirmar que el estado de selección de resultados (checkboxes) no cambió por
   haber abierto la vista previa.
6. Borrar (fuera de la app) un archivo que aparece en los resultados y, sin repetir la búsqueda,
   pulsar **Mostrar en Finder** y **Ver contenido** sobre ese resultado: ambos deben informar del
   error sin crear ni tocar archivos.
7. Repetir el paso 6 con un archivo al que se le quitan permisos de lectura, si es viable en el
   entorno de pruebas.
8. Confirmar que ningún `.replacer-backup` aparece nunca como resultado ni, por tanto, con estas
   acciones disponibles.
9. Repetir 2–3 con la app empaquetada (`dist/Replacer.app`), no solo con `swift run`, siguiendo la
   nota ya existente sobre foco de paneles nativos.

## 9. Notas de implementación

- No se necesita ningún permiso nuevo de macOS: `NSWorkspace.activateFileViewerSelecting` y la
  lectura de archivos ya usan las mismas rutas a las que el usuario dio acceso al elegir el
  directorio o escribir la ruta.
- Mantener el visor de contenido **de solo lectura** de forma explícita (`isEditable = false`) es
  importante: si se activa por error la edición, un usuario podría modificar el archivo desde la
  vista previa sin pasar por el flujo de confirmación y backup de `replaceSelected()`, rompiendo la
  garantía de seguridad descrita en `docs/ARCHITECTURE.md` ("Límites Intencionados").
- Si el archivo es grande (cerca del límite de 5 MB) y tiene muchas coincidencias, preferir acotar
  el resaltado (ver 5.2.1) antes que optimizar prematuramente el render completo; no hay indicios
  todavía de que sea un problema real.
