<!-- generated-by: gsd-doc-writer -->
# Pruebas

## Framework Y Alcance

Las pruebas nativas usan Swift Testing y viven en `Tests/FileReplaceCoreTests/`. Cubren el módulo `FileReplaceCore`, que concentra el comportamiento crítico: búsqueda de archivos, rechazo de binarios/no UTF-8, reemplazo selectivo y creación de backups.

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

- app macOS nativa;
- app empaquetada `dist/Replacer.app`;
- búsqueda directa y recursiva;
- reemplazo con backups;
- cancelación;
- rechazo de binarios/no UTF-8;
- versión Flask heredada;
- protección de `/api/replace`.

Última revisión manual registrada: 100% completada.
