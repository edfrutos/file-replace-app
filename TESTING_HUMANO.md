# Testing Humano

Guía de revisión manual para validar Replacer antes de hacer `git push`.

Estado: validación de búsqueda y reemplazo completada; acceso privado a actualizaciones pendiente de revisión manual.

## Objetivo

Comprobar que la app macOS nativa y la versión Flask heredada permiten buscar, revisar y reemplazar texto en archivos locales sin corromper datos, creando backups antes de escribir y bloqueando archivos no editables.

## Preparación

Trabaja siempre sobre una carpeta descartable.

```bash
mkdir -p /tmp/replacer-human-test/nivel1/nivel2
printf 'alpha beta alpha\nsegunda linea alpha\n' > /tmp/replacer-human-test/app.txt
printf 'sin coincidencias\n' > /tmp/replacer-human-test/otro.txt
printf 'alpha nested\n' > /tmp/replacer-human-test/nivel1/app.txt
printf 'alpha deep\n' > /tmp/replacer-human-test/nivel1/nivel2/app.txt
printf '\x00\x01\x02' > /tmp/replacer-human-test/binario.txt
printf '\xff\xfe\xfd' > /tmp/replacer-human-test/no-utf8.txt
```

Estado inicial esperado:

```text
/tmp/replacer-human-test/
  app.txt                  # 3 ocurrencias de alpha
  otro.txt                 # 0 ocurrencias
  binario.txt              # bytes nulos, debe rechazarse
  no-utf8.txt              # UTF-8 invalido, debe rechazarse
  nivel1/app.txt           # 1 ocurrencia
  nivel1/nivel2/app.txt    # 1 ocurrencia
```

## Pruebas Automatizadas Previas

Ejecuta antes de la revisión manual:

```bash
swift test
swift build --product Replacer
python3 -m py_compile app.py
```

Aceptación:

- `swift test` pasa con 10 tests.
- `swift build --product Replacer` compila.
- `python3 -m py_compile app.py` no muestra errores.

## App macOS Nativa

Arranque:

```bash
swift run Replacer
```

### 0. Acceso A Actualizaciones

- [ ] La cabecera muestra el botón `Actualizaciones`.
- [ ] El botón muestra un diálogo con la versión `1.1.0` y la limitación de acceso privado.
- [ ] Al confirmar, abre `edfrutos/file-replace-app/releases` en el navegador.
- [ ] `Replacer > Buscar actualizaciones…` muestra el mismo diálogo.
- [ ] Un destinatario autorizado puede ver las releases usando su sesión de GitHub.
- [ ] Un usuario sin permisos no recibe contenido privado y la app local sigue funcionando.
- [ ] Replacer no solicita ni almacena tokens y no instala nada automáticamente.

### 1. Estado Inicial

- [x] La ventana abre sin errores.
- [x] El panel lateral muestra controles de ubicacion, busqueda y acciones.
- [x] El boton `Buscar coincidencias` esta deshabilitado hasta seleccionar directorio, archivo y texto de busqueda.
- [x] El boton `Reemplazar seleccionados` esta deshabilitado sin resultados seleccionados.

### 2. Seleccion De Directorio

Usa el selector nativo y elige:

```text
/tmp/replacer-human-test
```

Aceptación:

- [x] La ruta seleccionada se muestra en pantalla.
- [x] El selector de archivo lista archivos de texto directos del directorio.
- [x] No debe bloquearse al listar archivos.
- [x] Archivos claramente binarios pueden aparecer por nombre si su extension no esta bloqueada, pero deben rechazarse al leer.

### 3. Busqueda No Recursiva Con Coincidencias

Configura:

```text
Archivo: app.txt
Texto a buscar: alpha
Texto de reemplazo: omega
Buscar en subdirectorios: desactivado
```

Accion:

- [x] Pulsa `Buscar coincidencias`.

Aceptación:

- [x] Se muestra 1 archivo con coincidencias.
- [x] El resultado corresponde a `app.txt` de la raiz.
- [x] El conteo muestra 3 coincidencias.
- [x] La preview marca la primera coincidencia.
- [x] El resultado aparece seleccionado por defecto.

### 4. Reemplazo Con Backup

Con el resultado anterior seleccionado:

- [x] Pulsa `Reemplazar seleccionados`.
- [x] Confirma el dialogo.

Aceptación:

- [x] La app avisa de que creara backup antes de escribir.
- [x] El log final muestra 3 reemplazos.
- [x] El log muestra el nombre del backup.
- [x] `/tmp/replacer-human-test/app.txt` contiene `omega`.
- [x] Existe `/tmp/replacer-human-test/app.txt.replacer-backup`.
- [x] El backup conserva el contenido original con `alpha`.

Comprueba en terminal:

```bash
cat /tmp/replacer-human-test/app.txt
cat /tmp/replacer-human-test/app.txt.replacer-backup
```

### 5. Backup Incremental

Configura:

```text
Archivo: app.txt
Texto a buscar: omega
Texto de reemplazo: alpha
Buscar en subdirectorios: desactivado
```

Accion:

- [x] Busca.
- [x] Reemplaza seleccionados.

Aceptación:

- [x] Se crea un segundo backup con sufijo incremental, por ejemplo `app.txt.replacer-backup-1`.
- [x] No se sobrescribe el backup anterior.
- [x] El contenido final vuelve a tener `alpha`.

### 6. Busqueda Sin Coincidencias

Configura:

```text
Archivo: otro.txt
Texto a buscar: alpha
Texto de reemplazo: omega
Buscar en subdirectorios: desactivado
```

Aceptación:

- [x] La app informa que no hay coincidencias.
- [x] No aparecen resultados seleccionables.
- [x] `Reemplazar seleccionados` sigue deshabilitado.
- [x] No se crea ningun backup para `otro.txt`.

### 7. Archivo Inexistente

Si la UI permite seleccionar o escribir un nombre no existente, prueba:

```text
Archivo: inexistente.txt
Texto a buscar: alpha
```

Aceptación:

- [x] La app informa que no se encontro el archivo.
- [x] No se crea backup.
- [x] No hay escritura en disco.

### 8. Busqueda Recursiva

Configura:

```text
Archivo: app.txt
Texto a buscar: alpha
Texto de reemplazo: gamma
Buscar en subdirectorios: activado
Profundidad: 3
```

Aceptación al buscar:

- [x] Se muestran 3 archivos con coincidencias: raiz, `nivel1/app.txt` y `nivel1/nivel2/app.txt`.
- [x] Todos aparecen seleccionados inicialmente.
- [x] La barra de resultados permite seleccionar todo y limpiar seleccion.

Aceptación al reemplazar solo algunos:

- [x] Desmarca uno de los resultados.
- [x] Reemplaza seleccionados.
- [x] Solo cambian los archivos seleccionados.
- [x] Cada archivo modificado tiene su backup.
- [x] El archivo desmarcado no cambia y no genera backup nuevo.

### 9. Profundidad Recursiva

Restaura o recrea los fixtures si hace falta. Esta prueba necesita que `nivel1/nivel2/app.txt` siga conteniendo `alpha`.

Importante: cambiar el slider de profundidad no relanza la busqueda automaticamente. Despues de cambiar la profundidad, pulsa otra vez `Buscar coincidencias`.

Configura:

```text
Archivo: app.txt
Texto a buscar: alpha
Buscar en subdirectorios: activado
Profundidad: 1
```

Aceptación:

- [x] La busqueda no debe incluir `nivel1/nivel2/app.txt`.
- [x] Al subir la profundidad y pulsar de nuevo `Buscar coincidencias`, el archivo profundo vuelve a aparecer.

### 10. Rechazo De Binarios Y No UTF-8

Prueba con:

```text
Archivo: binario.txt
Texto a buscar: alpha
```

y despues:

```text
Archivo: no-utf8.txt
Texto a buscar: alpha
```

Aceptación:

- [x] La app rechaza el archivo como no editable o no UTF-8.
- [x] No se crea backup.
- [x] No se modifica el archivo.

### 11. Reemplazo Por Texto Vacio

Configura:

```text
Archivo: app.txt
Texto a buscar: alpha
Texto de reemplazo: 
```

Aceptación:

- [x] La app permite reemplazo por cadena vacia.
- [x] El resultado elimina las ocurrencias.
- [x] Se crea backup antes de escribir.

### 12. Cancelacion

Configura una busqueda valida y pulsa `Reemplazar seleccionados`.

Cuando aparezca el dialogo nativo `Confirmar reemplazo`, cancela de una de estas formas:

- pulsa el boton `Cancelar`;
- o pulsa `Esc`.

No pulses `Reemplazar` en esta prueba.

Aceptación:

- [x] Al cancelar el dialogo, no se modifica ningun archivo.
- [x] No se crea backup nuevo.

## App Empaquetada

Genera el bundle:

```bash
scripts/build-macos-app.sh
```

Aceptación:

- [x] Se crea `dist/Replacer.app`.
- [x] El bundle se verifica con `codesign --verify --deep --strict`.
- [x] La app abre desde Finder o terminal.
- [x] El icono aparece correctamente.
- [x] Repite al menos las pruebas 2, 3 y 4 con el bundle.

Genera el DMG:

```bash
scripts/build-dmg.sh
```

Aceptación:

- [x] Se crea `dist/Replacer-1.1.0.dmg`.
- [x] El DMG se verifica correctamente.
- [x] Al montar el DMG, contiene `Replacer.app` y un enlace a `Applications`.

## Version Flask Heredada

Arranque:

```bash
python -m venv .venv
source .venv/bin/activate
pip install flask
python app.py
```

Abre:

```text
http://localhost:5050
```

### 13. Indicador Legacy

- [x] La UI muestra que es la version web heredada.
- [x] El servidor imprime en terminal que la app principal es la version SwiftUI.

### 14. Autocompletado De Directorio

En la UI web:

```text
Directorio: /tmp/replacer-human-test
Nombre de archivo: app.txt
```

Aceptación:

- [x] El autocompletado lista archivos directos.
- [x] El selector no lista mas de 50 archivos.

### 15. Busqueda Web

Configura:

```text
Directorio: /tmp/replacer-human-test
Nombre de archivo: app.txt
Cadena a buscar: alpha
Cadena de reemplazo: web
Alcance: solo este directorio
```

Aceptación:

- [x] La UI muestra coincidencias.
- [x] La preview marca la coincidencia.
- [x] Se puede continuar a confirmacion.

### 16. Reemplazo Web Con Backup

Aceptación:

- [x] La pantalla de confirmacion indica que se creara `.replacer-backup`.
- [x] Al confirmar, se modifica el archivo.
- [x] La pantalla final muestra reemplazos y ruta de backup.
- [x] El backup conserva el contenido anterior.

### 17. Proteccion De Ruta No Autorizada

Prueba directa con `curl` sobre una ruta que no se haya buscado antes:

```bash
curl -s -X POST http://localhost:5050/api/replace \
  -H 'Content-Type: application/json' \
  -d '{"filepath":"/tmp/replacer-human-test/otro.txt","search":"sin","replace":"con"}'
```

Aceptación:

- [x] La respuesta contiene `Primero debes localizar este archivo`.
- [x] `otro.txt` no cambia.

### 18. Rechazo Web De Binarios Y No UTF-8

Busca `binario.txt` y `no-utf8.txt` desde la UI o con `/api/search`.

Aceptación:

- [x] La API devuelve error de archivo no editable o no UTF-8.
- [x] No se escribe ningun backup.
- [x] El archivo original queda intacto.

## Limpieza

Cuando termines:

```bash
rm -rf /tmp/replacer-human-test
```

Si arrancaste Flask:

```bash
deactivate
```

## Criterios De Aceptacion Final

- [x] La app nativa busca en modo directo y recursivo.
- [x] La seleccion multiple funciona y solo modifica archivos seleccionados.
- [x] Todo reemplazo crea backup antes de escribir.
- [x] Los backups no se sobrescriben.
- [x] Cancelar no escribe ni crea backup.
- [x] Binarios y no UTF-8 se rechazan.
- [x] Reemplazo por cadena vacia funciona.
- [x] El bundle `dist/Replacer.app` se genera y abre.
- [x] La version Flask heredada funciona localmente y queda claramente marcada como legacy.
- [x] `/api/replace` no permite modificar rutas no autorizadas por busqueda previa.
- [x] No se han usado archivos reales del usuario durante la prueba.
