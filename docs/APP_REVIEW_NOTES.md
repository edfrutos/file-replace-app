<!-- generated-by: hand -->
# Notas para App Review

## 1.4.0: reenvío tras el rechazo por 4.3 y 4.2.6

La 1.3.0 se rechazó por las guidelines 4.3 (Spam) y 4.2.6 (App Generation
Services). Apple ofrece dos caminos: reenviar con cambios sustanciales o, sin
reenviar, contestar sus 9 preguntas. La 1.4.0 sigue el primero y añade además las
respuestas, para que el revisor tenga todo el contexto.

Antes de enviar:

1. Revisa que las respuestas siguen siendo ciertas el día del envío (otras apps
   de la cuenta, código compartido, beta). Un dato falso es peor que un «no».
2. No ha habido beta externa y la pregunta 4 lo dice así. Si más adelante la
   hay, sustituye esa respuesta por los testers y sus comentarios reales.
3. Graba el vídeo con el build que envías, instalado desde TestFlight.
4. Pega **Notas para la revisión** en *Información de revisión de apps ▸ Notas*
   (máximo 4000 caracteres) y **Respuesta a las preguntas** como respuesta en el
   hilo del rechazo, en *Distribución ▸ Revisión de apps*. Adjunta el vídeo en el
   hilo.

### Grabación de pantalla (1.4.0)

Con el sistema en inglés, o con `Ajustes ▸ Idioma ▸ English`, para que el revisor
no dependa de traducciones. Prepara `~/Desktop/Demo` con `a.txt`
(`hello world, hello`), `b.txt` (`hello`) y un `pairs.csv`:

```
find,replace
hello,goodbye
world,planet
```

1. ⇧⌘5 ▸ Grabar toda la pantalla ▸ Grabar.
2. Abre Replacer desde el Dock (el vídeo debe empezar con el arranque).
3. Arrastra la carpeta `Demo` desde Finder a la ventana.
4. *Recipes ▸ Import Pairs from CSV…* ▸ `pairs.csv`.
5. *Find Matches*. Despliega *Review matches one by one* en `a.txt` y excluye una
   coincidencia.
6. Marca los dos archivos ▸ *Replace Selected* ▸ confirmar.
7. Muestra en Finder un `.replacer-backup`.
8. *History* ▸ *Restore all* ▸ confirmar; abre `a.txt` con la lupa: vuelve a
   `hello world, hello`.
9. Clic derecho en `Demo` en Finder ▸ Servicios ▸ *Find and Replace with Replacer*.
10. *Start Over* (⌘N) y *Replacer ▸ Settings…* (idioma y apariencia).
11. Detén la grabación.

### Notas para la revisión

```text
Replacer 1.4.0 is a substantially reworked version of the build rejected under guidelines 4.3 and 4.2.6. Our answers to the questions in that message are in the reply to the rejection; a screen recording of the whole flow is attached there.

WHAT CHANGED SINCE 1.3.0
- Several find -> replace pairs applied in a single pass (they never chain), saved recipes, and import of pairs from CSV.
- Review of every single match, with its line and the before -> after change; individual matches can be excluded.
- Replacement history: undo a whole batch or a single file from its backup, only if the file was not edited afterwards.
- Safety: a file that changed after the search is never written.
- Drag a folder onto the window or the Dock icon, and a Finder service (right-click a folder > Services > Find and Replace with Replacer).
- English interface (it follows the system language, with a Language option in Settings), and Start Over (Cmd-N).

HOW TO TEST
No account or setup is needed.
1. Create a folder with two text files containing "hello world, hello" and "hello".
2. Launch Replacer and drag the folder onto the window (or click "Choose Folder"). Under App Sandbox, Replacer only accesses folders chosen this way.
3. Type "hello" in Find and "goodbye" in Replace with. "Add pair" adds a second pair, e.g. "world" -> "planet".
4. Click "Find Matches". Expand "Review matches one by one" and uncheck any match you want to keep.
5. Check the files and click "Replace Selected". A .replacer-backup copy is created next to each file.
6. Click "History" and "Restore all": the files go back to their original content.
7. Settings offers Language (System, Español, English) and Appearance.

The app makes no network connections, uses no third-party SDKs and collects no data.
```

### Respuesta a las preguntas

```text
Hello, and thank you for the detailed feedback. We have resubmitted Replacer as version 1.4.0 with substantial changes (listed in the review notes), and we answer each question below.

1. WHAT THE APP DOES
Replacer changes text across many files of a folder in a controlled, reversible way. The user chooses a folder, enters one or more "find -> replace" pairs and searches. Each file is listed with every match, its line number and a before -> after preview; nothing is selected by default, and the user can exclude individual matches. On confirmation, Replacer writes a backup next to each file, applies all pairs in a single pass, refuses to write any file that changed since the search, and records the operation in a history from which any batch or single file can be restored, but only if it was not edited afterwards. The problem it solves: making the same set of text changes across dozens of files (a domain move, a renamed product, a changed path or setting) without opening them one by one and without the risk of an irreversible blind "replace all".

2. INTENDED USERS
Web developers and designers maintaining static sites and templates; developers updating configuration files, scripts and documentation; technical writers maintaining Markdown or HTML documentation; and people who keep notes or data as plain text. Typically users comfortable with files and folders, but who prefer a native Mac tool with review and undo to command-line tools such as sed.

3. NEED OR GAP
Command-line tools (sed, perl) are powerful but unforgiving: they apply changes without per-match review and offer no undo beyond optional backup files the user must restore by hand. Full code editors with project-wide replace assume a project open in the editor, and once the edited files are saved and closed there is no history to return to. Replacer is a focused, sandboxed tool built around safety for exactly this task: several pairs applied in one pass without chaining, per-match review before writing, automatic per-file backups, refusal to write files that changed since the search, and a persistent history that restores earlier states only when it is safe. Pair lists can be imported from a spreadsheet (CSV), so a whole migration can be prepared outside the app and reviewed inside it.

4. BETA TESTING
Replacer has not had an external beta. It has been tested by the developer only: on real folders of websites, configuration files and documentation, through TestFlight builds installed on our own Mac, and with an automated test suite of 31 tests covering search, replacement, backups, the refusal to write changed files and the history restore. The 1.4.0 changes come from that use and from your review of 1.3.0: multiple pairs and CSV import (to avoid running the same search several times), per-match review (to keep specific occurrences unchanged), the history with safe restore (to undo a batch without searching for backups by hand) and the English interface.

5. STANDALONE OR SUITE
Replacer is a standalone product and not part of a suite. The other apps on our developer account have purposes unrelated to Replacer:
- Gestor de Correos Gmail (on the App Store): organizes a Gmail account from the Mac: batch search, labelling and archiving, automatic rules and .eml export, processed on the user's computer.
- Extractor URL (not on the App Store): converts a web page into clean Markdown, HTML or plain text.
- TablaTeca (not on the App Store): organizes personal collections as table catalogues, with rows that hold images, documents and videos, stored on the Mac.
- GestorTareas (not on the App Store): creates, assigns and tracks issues by marking their exact location on a floor plan, with photos, documents and real-time notifications synced with a web service.
- EDF-Catálogo (never submitted for review): catalogues of collections and inventories with images, videos and documents, available on the Mac and the web.
None of them searches or edits the content of the user's files.

6. CONSOLIDATION INTO ANOTHER APP
No. None of our other apps works with folders of text files, so adding file search and replacement to any of them would be unrelated to their purpose and confusing for their users.

7. SHARED CODE WITH OUR OTHER APPS
No. Replacer's code, its core module (search, replacement, backup, history) and its icon were written for this app and are not used by any other app on our account.

8. SHARED CODE WITH THIRD-PARTY APPS
No. Replacer uses only Apple frameworks (SwiftUI, AppKit, Foundation). It contains no third-party SDK, template or content library.

9. CLIENT OR THIRD PARTY
No. Replacer was conceived, designed and developed by the account holder, Eugenio de Frutos, who provides all of its content and branding. It was not built from a commercial template or app generation service.

Best regards,
Eugenio de Frutos
```

## 1.3.0: información pedida (Guideline 2.1)
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

### Grabación de pantalla

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

### Respuesta

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
