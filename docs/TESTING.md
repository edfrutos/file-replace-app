<!-- generated-by: gsd-doc-writer -->
# Pruebas

## Framework Y Alcance

Las pruebas nativas usan Swift Testing y viven en `Tests/FileReplaceCoreTests/`. Cubren el módulo `FileReplaceCore`, que concentra el comportamiento crítico: rastreo de todos los archivos del alcance, filtro glob por nombre, omisión de binarios/no UTF-8/archivos grandes, reemplazo selectivo, rechazo de archivos de solo lectura, creación de backups y comparación de versiones.

La versión Flask heredada no tiene suite automatizada dedicada en el repositorio. Si se añaden tests Python, deberían vivir en un directorio separado y usar fixtures temporales.

## Ejecutar Todas Las Pruebas

```bash
swift test
```

En entornos con sandbox estricto, SwiftPM puede necesitar permisos para escribir cachés en el directorio de usuario. Si aparece un error de `ModuleCache` o `Operation not permitted`, vuelve a ejecutar el comando fuera del sandbox.

## Ejecutar Build De La App

```bash
swift build --product Replacer
```

Este comando verifica que la app SwiftUI completa compila, no solo el target testeado.

## Escribir Nuevas Pruebas

Añade tests en:

```text
Tests/FileReplaceCoreTests/FileReplaceCoreTests.swift
```

Patrones actuales:

- Usa `TemporaryFixture` para crear directorios y archivos temporales.
- No uses rutas reales del usuario.
- Comprueba tanto el contenido final como los backups cuando el test toque reemplazos.
- Reproduce casos de error con archivos binarios o datos no UTF-8.
- Comprueba tags con prefijo `v`, componentes omitidos y prereleases al probar `AppVersion`.

Ejemplo de intención de test:

```swift
@Test("replace creates a backup before writing")
func replaceCreatesBackup() throws {
    // Crear fixture temporal, buscar, reemplazar y verificar backup + contenido final.
}
```

## Cobertura

No hay umbrales de cobertura configurados en el repositorio.

## CI

No hay workflows de GitHub Actions ni otra configuración CI versionada. Antes de abrir una PR, ejecuta localmente:

```bash
swift test
swift build --product Replacer
scripts/build-dmg.sh
python3 -m py_compile app.py
```

Si cambias la versión Flask y tienes `flask` instalado, haz también una comprobación manual en `http://localhost:5050` usando una carpeta descartable.

## Validación Manual

El checklist completo de validación humana está en [`TESTING_HUMANO.md`](../TESTING_HUMANO.md). Cubre:

- app macOS nativa y app empaquetada `dist/Replacer.app`;
- selección de directorio por panel y por ruta escrita/pegada;
- filtro de nombre glob y búsqueda sin filtro (todos los archivos);
- búsqueda directa y recursiva con poda de directorios de ruido;
- omisión de binarios, no UTF-8 y archivos mayores de 5 MB;
- selección previa obligatoria y reemplazo con backups;
- rechazo de archivos de solo lectura;
- cancelación;
- versión Flask heredada y protección de `/api/replace`.

Última pasada manual completa registrada: v1.1.0. El checklist está actualizado para v1.2.0 y pendiente de una pasada completa.
