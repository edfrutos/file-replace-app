<!-- generated-by: hand -->
# Notas para App Review

En la primera revisión de la 1.3.0 (29/10/2026), Apple pidió información
adicional (Guideline 2.1 - Information Needed): una grabación de pantalla y
respuestas sobre propósito, uso, servicios externos, regiones y regulación.

El texto de abajo se envía como respuesta en **Distribución ▸ Revisión de apps**
y se pega también en **Información de revisión de apps ▸ Notas** de cada versión
(máximo 4000 caracteres). Está en inglés para que el revisor no dependa de una
traducción; la interfaz está en español, así que cada control lleva su
traducción entre corchetes.

Antes de cada envío, revisa que siga siendo cierto: número de versión y build
del punto 1 y nombres de los controles del punto 3 (ver `ContentView.swift`).

## Grabación de pantalla

Hazla con el build que está en revisión, instalado desde TestFlight, no con el
de Xcode.

1. Prepara `~/Desktop/Demo` con dos o tres `.txt` que contengan `hello`.
2. ⇧⌘5 ▸ Grabar toda la pantalla ▸ Grabar.
3. Abre Replacer desde el Dock o Aplicaciones (Apple exige que el vídeo empiece
   con el arranque de la app).
4. Seleccionar directorio ▸ `Demo`.
5. `hello` en *Texto a buscar*, `goodbye` en *Texto de reemplazo* ▸ Buscar
   coincidencias.
6. Lupa sobre un resultado (abre y cierra la hoja); carpeta sobre un resultado
   (Finder) y vuelve a la app.
7. Seleccionar todo ▸ Reemplazar seleccionados ▸ confirmar; la lista se
   actualiza.
8. En Finder, muestra el `.replacer-backup` junto al archivo.
9. Replacer ▸ Ajustes… ▸ Oscuro y vuelta a Automático.
10. Detén la grabación con ⏹ en la barra de menús. Adjunta el `.mov` a la
    respuesta.

## Respuesta

```text
Hello, and thank you for reviewing Replacer.

1. SCREEN RECORDING
Attached is a screen recording made on a Mac running the latest version of macOS with the submitted build (1.3.0, build 3). It starts by launching the app and shows the full flow: choosing a folder, searching, reviewing matches, replacing, checking the backup file, and the appearance setting. Replacer has no accounts, no user-generated content and no paid content or in-app purchases.

2. PURPOSE AND AUDIENCE
Replacer finds a piece of text in every file of a folder chosen by the user and replaces it only in the files the user explicitly selects, after reviewing each match. It solves a common problem for developers, web designers and anyone who maintains many text files (HTML, CSS, code, Markdown, configuration files): changing a URL, a name, a path or a setting repeated across dozens of files without opening them one by one and without a blind "replace all". Before writing any file, Replacer saves a backup copy next to the original (.replacer-backup). It only edits UTF-8 text files; binaries, non-UTF-8 files and files larger than 5 MB are skipped.

3. HOW TO USE IT
No login, account or special setup is needed. The interface is in Spanish; the English meaning of each control is given in brackets.
a) Create a test folder with a few plain-text files, for example two .txt files containing the word "hello".
b) Launch Replacer and click "Seleccionar directorio" [Select folder]. Choose the test folder in the standard macOS open panel. Under App Sandbox, Replacer can only access the folder chosen there.
c) Optional: "Filtro de nombre (opcional)" [Name filter] accepts patterns such as *.txt. Leave it empty to include all files.
d) Type the text to find in "Texto a buscar" [Text to find] (hello) and the new text in "Texto de reemplazo" [Replacement text] (goodbye). "Buscar en subdirectorios" [Search subfolders] and the "Profundidad" [Depth] slider include subfolders.
e) Click "Buscar coincidencias" [Find matches]. Each file with matches is listed with its number of matches and a preview. The magnifier icon shows the whole file with every match highlighted (read-only); the folder icon reveals the file in Finder.
f) No result is selected by default. Tick the files to change, or use "Seleccionar todo" [Select all].
g) Click "Reemplazar seleccionados" [Replace selected] and confirm. The files are updated, a .replacer-backup copy of each one is created next to it, and the list refreshes automatically.
h) Replacer > Ajustes... [Settings] offers Light, Dark or Automatic appearance.

4. EXTERNAL SERVICES
None. Replacer works entirely on the Mac: it makes no network connections and uses no third-party services, SDKs, analytics, authentication, payment or AI services. It collects no data.

5. REGIONAL DIFFERENCES
None. The app works the same way in every region. The interface is in Spanish in all regions.

6. REGULATED INDUSTRY OR THIRD-PARTY MATERIAL
Not applicable. Replacer does not operate in a regulated industry and contains no protected third-party material.

Best regards,
Eugenio de Frutos
```
