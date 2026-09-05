# Testing Humano — Replacer 1.2.0

Guía de revisión manual para validar Replacer antes de hacer `git push` o de empaquetar una release.

Estado: pasada manual completa al 100%, incluida la funcionalidad de localizar en Finder y ver contenido (2026-09-05).

## Objetivo

Comprobar que la app macOS nativa localiza una cadena exacta en **cualquier archivo** de un
directorio (o de su árbol hasta la profundidad indicada), permite revisar y desmarcar resultados,
y reemplaza solo los archivos marcados creando una copia `.replacer-backup` antes de escribir,
sin corromper binarios ni tocar archivos de solo lectura.

## Cambios respecto a 1.1.0 que hay que validar

- El campo de archivo pasa a ser un **filtro de nombre opcional** (patrón glob). Vacío = todos los archivos.
- Ya no hay lista negra de extensiones: se rastrea todo y se **omiten** binarios, no‑UTF‑8 y archivos > 5 MB.
- La búsqueda recursiva incluye ocultos, poda directorios de ruido y nunca toca los `.replacer-backup`.
- Tras buscar, **ningún resultado queda marcado**: hay que seleccionarlos antes de poder reemplazar.
- Los archivos de solo lectura se informan como error por archivo y no se modifican.
- Búsqueda y reemplazo son **asíncronos**: la ventana no se congela.
- Los campos "Texto a buscar" / "Texto de reemplazo" no aplican comillas curvas ni guiones largos.
- El panel lateral está **siempre visible** (split fijo, sin `NavigationSplitView`).
- La ruta del directorio se puede **escribir o pegar** además de elegirla con el panel.
- La versión mostrada es **1.2.0**.

## Preparación

Trabaja siempre sobre una carpeta descartable.

```bash
rm -rf /tmp/replacer-human-test
mkdir -p /tmp/replacer-human-test/nivel1/nivel2
mkdir -p /tmp/replacer-human-test/node_modules/pkg
mkdir -p /tmp/replacer-human-test/apps/client

printf 'alpha beta alpha\nsegunda linea alpha\n' > /tmp/replacer-human-test/app.txt
printf 'sin coincidencias\n'                     > /tmp/replacer-human-test/otro.txt
printf 'alpha nested\n'                          > /tmp/replacer-human-test/nivel1/app.txt
printf 'alpha deep\n'                            > /tmp/replacer-human-test/nivel1/nivel2/app.txt
printf '# alineado con apps/client/.env — Mongo/S3\nTOKEN="abc-123"\n' > /tmp/replacer-human-test/apps/client/.env
printf 'alpha en dependencia\n'                  > /tmp/replacer-human-test/node_modules/pkg/app.txt
printf '\x00\x01\x02'                            > /tmp/replacer-human-test/binario.dat
printf '\xff\xfe\xfd'                            > /tmp/replacer-human-test/no-utf8.txt
yes alpha | head -c 6000000                      > /tmp/replacer-human-test/grande.txt
printf 'alpha solo lectura\n'                    > /tmp/replacer-human-test/readonly.txt
chmod 0444 /tmp/replacer-human-test/readonly.txt
```

Estado inicial esperado:

```text
/tmp/replacer-human-test/
  app.txt                     # 3 ocurrencias de alpha
  otro.txt                    # 0 ocurrencias
  binario.dat                 # bytes nulos -> se omite al leer
  no-utf8.txt                 # UTF-8 invalido -> se omite al leer
  grande.txt                  # ~6 MB -> se omite por tamano
  readonly.txt                # 1 ocurrencia, permisos 0444
  nivel1/app.txt              # 1 ocurrencia
  nivel1/nivel2/app.txt       # 1 ocurrencia
  apps/client/.env            # oculto, contiene el guion largo "—"
  node_modules/pkg/app.txt    # 1 ocurrencia, dentro de un dir podado
```

## 0. Pruebas automatizadas previas

```bash
swift test
swift build --product Replacer
python3 -m py_compile app.py
```

Aceptación:

- [x] `swift test` pasa con **14 tests** (2 de `AppVersion`, 12 de `FileReplaceService`).
- [x] `swift build --product Replacer` compila sin errores ni warnings nuevos.
- [x] `python3 -m py_compile app.py` no muestra errores.

## 1. Arranque de la app

Para la revisión manual usa el **bundle**, no `swift run` (sin `.app` real el foco de teclado y el
panel del sistema fallan de forma intermitente en macOS 26/27):

```bash
script/build_and_run.sh
```

Aceptación:

- [x] La app abre sin crash (regresión de `Bundle.module` corregida en 1.2.0).
- [x] El **panel lateral es visible de inmediato** con las secciones Ubicación, Búsqueda y Acciones.
- [x] El botón `Actualizaciones` de la cabecera muestra un diálogo con la versión `1.2.0`.
- [x] `Buscar coincidencias` está deshabilitado hasta tener directorio y texto de búsqueda.
- [x] `Reemplazar seleccionados` está deshabilitado sin nada marcado.

## 2. Selección de directorio: panel

- [x] Pulsa `Seleccionar directorio` y elige `/tmp/replacer-human-test`.
- [x] La ruta aparece bajo el botón y el estado invita a escribir el texto a buscar.
- [x] Si el panel se cancela, el estado lo indica y sugiere usar el campo de ruta.

## 3. Selección de directorio: ruta escrita/pegada

- [x] Borra la selección reiniciando la app o eligiendo otra carpeta.
- [x] En el campo `~/ruta/al/proyecto` pega `/tmp/replacer-human-test` y pulsa `Usar` (o Intro).
- [x] Se fija el mismo directorio que con el panel.
- [x] Con una ruta inexistente o que sea un archivo, el estado avisa y no cambia el directorio.
- [x] El campo acepta pegar con Cmd+V y expande `~`.

## 4. Búsqueda sin filtro de nombre (todos los archivos), no recursiva

Configura:

```text
Filtro de nombre: (vacío)
Texto a buscar: alpha
Texto de reemplazo: omega
Buscar en subdirectorios: desactivado
```

Aceptación:

- [x] Durante la búsqueda el estado muestra `Buscando…` y la ventana sigue respondiendo.
- [x] Aparecen los archivos del **directorio raíz** con `alpha`: `app.txt` y `readonly.txt`.
- [x] `otro.txt` no aparece (0 coincidencias).
- [x] El estado indica cuántos archivos se han omitido (`binario.dat`, `no-utf8.txt`, `grande.txt`).
- [x] **Ningún resultado viene marcado.**
- [x] `Reemplazar seleccionados` sigue deshabilitado hasta marcar algo.

## 5. Selección previa obligatoria y reemplazo con backup

- [x] Marca solo `app.txt` (deja `readonly.txt` sin marcar).
- [x] `Reemplazar seleccionados` se habilita al marcar.
- [x] Púlsalo y confirma el diálogo.

Aceptación:

- [x] El log final muestra `app.txt: 3 reemplazo(s)` y el nombre del backup.
- [x] `/tmp/replacer-human-test/app.txt` contiene `omega`.
- [x] Existe `/tmp/replacer-human-test/app.txt.replacer-backup` con el contenido original (`alpha`).
- [x] `readonly.txt` no se ha tocado y no tiene backup.

```bash
cat /tmp/replacer-human-test/app.txt
cat /tmp/replacer-human-test/app.txt.replacer-backup
```

## 6. Backup incremental

Configura `Texto a buscar: omega`, `Texto de reemplazo: alpha`, no recursiva. Busca, marca `app.txt`, reemplaza.

Aceptación:

- [x] Se crea un segundo backup con sufijo, p. ej. `app.txt.replacer-backup-1`.
- [x] No se sobrescribe el backup anterior.
- [x] El contenido final vuelve a tener `alpha`.

## 7. Filtro de nombre glob

Configura:

```text
Filtro de nombre: *.env*
Texto a buscar: —          (pega el guion largo del archivo .env, sin comillas)
Buscar en subdirectorios: activado
Profundidad: 5
```

Aceptación:

- [x] Aparece `apps/client/.env` (archivo oculto encontrado por el patrón).
- [x] No aparece ningún `.txt`.
- [x] La preview marca el guion largo, es decir, **el campo de texto no lo convirtió** en otro carácter.
- [x] Prueba también `Filtro de nombre: app.txt` recursivo: aparecen `app.txt`, `nivel1/app.txt`,
      `nivel1/nivel2/app.txt`, pero **no** `node_modules/pkg/app.txt` (directorio podado).

## 8. Búsqueda recursiva y profundidad

Configura `Filtro de nombre: app.txt`, `Texto a buscar: alpha`, recursiva, `Profundidad: 1`.

Aceptación:

- [x] Con profundidad 1 no aparece `nivel1/nivel2/app.txt`.
- [x] Al subir el slider a 3 y **volver a pulsar** `Buscar coincidencias`, sí aparece.
- [x] La barra de resultados permite `Seleccionar todo` y `Limpiar selección`.

## 9. Reemplazo parcial en recursivo

Con los `app.txt` del árbol en resultados (`alpha` -> `gamma`, recursivo, profundidad 3):

- [x] `Seleccionar todo`, luego desmarca `nivel1/nivel2/app.txt`.
- [x] Reemplaza seleccionados.
- [x] Solo cambian los archivos marcados; cada uno tiene su backup.
- [x] El archivo desmarcado no cambia y no genera backup nuevo.

## 10. Rechazo de binarios, no‑UTF‑8 y archivos grandes

Con `Filtro de nombre` vacío o apuntando a cada archivo, busca `alpha` sobre `binario.dat`,
`no-utf8.txt` y `grande.txt`.

Aceptación:

- [x] Ninguno aparece como resultado.
- [x] El estado los cuenta como omitidos.
- [x] No se crea backup ni se modifica ninguno.

## 11. Archivo de solo lectura

Configura `Texto a buscar: alpha`, no recursiva. Marca `readonly.txt` y reemplaza.

Aceptación:

- [x] El log muestra para `readonly.txt` un error de solo lectura.
- [x] `readonly.txt` conserva su contenido.
- [x] No se ha creado `readonly.txt.replacer-backup`.

## 12. Reemplazo por cadena vacía

`Texto a buscar: alpha`, `Texto de reemplazo:` vacío. Busca `app.txt`, marca, reemplaza.

Aceptación:

- [x] La app permite el reemplazo por cadena vacía (elimina ocurrencias).
- [x] Se crea backup antes de escribir.

## 13. Cancelación

Configura una búsqueda válida, marca un resultado y pulsa `Reemplazar seleccionados`.
En el diálogo `Confirmar reemplazo`, pulsa `Cancelar` o `Esc`.

Aceptación:

- [x] No se modifica ningún archivo.
- [x] No se crea ningún backup.

## 14. Límite de resultados

Opcional, sobre un árbol real grande (p. ej. la carpeta de un proyecto con muchos archivos):

- [x] Con filtro vacío y profundidad alta, si se superan 1000 archivos el estado lo advierte
      y sugiere acotar con un filtro de nombre o menos profundidad.

## 15. App empaquetada y DMG

```bash
scripts/build-macos-app.sh
```

Aceptación:

- [x] Se crea `dist/Replacer.app`.
- [x] `codesign --verify --deep --strict dist/Replacer.app` no da error.
- [x] La app abre desde Finder y **no crashea** al arrancar.
- [x] `Replacer > Acerca de` / cabecera muestran versión `1.2.0` (build 3).
- [x] Repite al menos las pruebas 2–5 con el bundle.

```bash
scripts/build-dmg.sh
```

Aceptación:

- [x] Se crea `dist/Replacer-1.2.0.dmg`.
- [x] `hdiutil verify` pasa.
- [x] Montado, contiene `Replacer.app` y un enlace a `Applications`.

## 16. Localizar en Finder y ver contenido

Busca una cadena que aparezca en varios archivos, incluidos algunos en subdirectorios
(activa la búsqueda recursiva).

- [x] Pulsa el icono de carpeta sobre un resultado de primer nivel: Finder pasa a primer
      plano con ese archivo seleccionado.
- [x] Pulsa el icono de carpeta sobre un resultado anidado (dentro de un subdirectorio):
      Finder selecciona el archivo correcto, no la carpeta raíz.
- [x] Pulsa el icono de lupa sobre documento en un resultado con varias coincidencias: se
      abre una hoja con el contenido completo del archivo y **todas** las coincidencias
      resaltadas, no solo la primera (compara con el fragmento corto de la fila).
- [x] Dentro de la hoja, pulsa `Mostrar en Finder`: el comportamiento es el mismo que desde
      la fila.
- [x] Cierra la hoja con `Cerrar` y confirma que la selección de checkboxes de los
      resultados no cambió por haber abierto la vista previa.
- [x] Fuera de la app, borra uno de los archivos que aparece en los resultados (sin repetir
      la búsqueda). Pulsa el icono de carpeta sobre ese resultado: la cabecera muestra un
      mensaje de error y Finder no se abre.
- [x] Sobre el mismo archivo borrado, pulsa el icono de lupa: la hoja muestra un mensaje de
      error en vez de contenido, y no crea ni modifica ningún archivo.
- [x] Confirma que ningún `.replacer-backup` aparece nunca como resultado de búsqueda (y por
      tanto tampoco tiene estas acciones disponibles).
- [x] Repite al menos los dos primeros pasos con la app empaquetada (`dist/Replacer.app`),
      no solo con `swift run`.

## 17. Versión Flask heredada (sin cambios en 1.2.0)

`app.py` no se ha tocado en esta release. Si necesitas revalidarla, sigue el checklist de la
versión web que había en 1.1.0: arranque en `http://localhost:5050`, indicador de legado,
autocompletado de directorio, búsqueda/reemplazo con backup y protección de `/api/replace`
frente a rutas no localizadas previamente.

```bash
python -m venv .venv && source .venv/bin/activate && pip install flask && python app.py
```

Aceptación mínima:

- [x] La UI web arranca y se marca claramente como versión heredada.
- [x] `/api/replace` rechaza rutas no localizadas antes por `/api/search`.
- [x] Binarios y no‑UTF‑8 se rechazan también en la versión web.

## Limpieza

```bash
chmod 0644 /tmp/replacer-human-test/readonly.txt 2>/dev/null
rm -rf /tmp/replacer-human-test
deactivate 2>/dev/null || true
```

## Criterios de aceptación final

- [x] `swift test` pasa con 14 tests; `swift build --product Replacer` compila.
- [x] El panel lateral es visible al arrancar y la app empaquetada no crashea.
- [x] Directorio seleccionable por panel y por ruta escrita/pegada.
- [x] Filtro de nombre vacío rastrea todos los archivos; el patrón glob acota por nombre.
- [x] Binarios, no‑UTF‑8 y archivos > 5 MB se omiten sin abortar la búsqueda.
- [x] La búsqueda recursiva poda `.git`, `node_modules`, `.venv`, `.build`, `__pycache__`, etc.
- [x] Tras buscar no hay nada marcado; solo se reemplazan los archivos marcados.
- [x] Todo reemplazo crea backup antes de escribir; los backups no se sobrescriben.
- [x] Los archivos de solo lectura se informan y no se modifican.
- [x] Los campos de búsqueda/reemplazo no alteran comillas ni guiones.
- [x] Cancelar el diálogo no escribe ni crea backup.
- [x] Mostrar en Finder y Ver contenido funcionan por resultado, sin alterar la selección de reemplazo ni el filesystem, y ambos informan del error si el archivo cambió o se borró.
- [x] La UI no se congela durante búsquedas o reemplazos largos.
- [x] `dist/Replacer-1.2.0.dmg` se genera y verifica.
- [x] No se han usado archivos reales del usuario durante la prueba.
