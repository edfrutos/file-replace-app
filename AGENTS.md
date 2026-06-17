# Repository Guidelines

## Project Structure & Module Organization

This repository contains a local file search/replace utility. The original implementation is Flask-based, and the native macOS implementation uses SwiftUI.

- `app.py` contains the legacy Flask server, API routes, filesystem search logic, and replacement logic.
- `static/index.html` contains the legacy browser UI, including styles and client-side JavaScript.
- `Package.swift` defines the native macOS Swift package.
- `Sources/FileReplaceCore/` contains the tested search and replace logic.
- `Sources/FileReplaceApp/` contains the SwiftUI app shell and views.
- `Tests/FileReplaceCoreTests/` contains Swift tests for filesystem behavior.
- `TESTING_HUMANO.md` contains the full manual validation checklist for release-style human testing.
- `docs/native-macos.md` documents the native app.
- `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT.md`, `docs/TESTING.md`, `docs/CONFIGURATION.md`, and `docs/API.md` document the current architecture, workflows, testing, configuration, and legacy Flask API.
- `scripts/build-macos-app.sh` packages the native executable as `dist/Replacer.app`.
- `scripts/build-dmg.sh` packages the native app into `dist/Replacer.dmg`.
- `favicon.ico` is the browser icon.
- `leeme.md` contains Spanish usage notes.
- `repomix-output.xml` is generated repository context and should not drive application behavior.

## Build, Test, and Development Commands

Run the native macOS app with Swift:

```bash
swift run Replacer
```

Run native tests:

```bash
swift test
```

Package the native app:

```bash
scripts/build-macos-app.sh
```

The legacy web app runs directly with Python and Flask:

```bash
pip install flask
python app.py
```

`python app.py` starts the legacy local server on `http://localhost:5050`.

For isolated development, prefer a virtual environment:

```bash
python -m venv .venv
source .venv/bin/activate
pip install flask
python app.py
```

## Coding Style & Naming Conventions

Use Python 3 with 4-space indentation. Keep backend functions small and named with `snake_case`, as in `find_files`, `find_in_file`, and `replace_in_file`. API routes should return JSON dictionaries with clear `error` or success fields.

Frontend code currently lives in one HTML file. Keep CSS custom properties in `:root`, use class names that describe UI roles, and avoid adding external JavaScript dependencies unless they simplify a real maintenance problem.

## Testing Guidelines

Native tests use Swift Testing and live under `Tests/FileReplaceCoreTests/`. Cover filesystem helpers with temporary directories and files rather than real paths:

```bash
swift test
```

If adding tests for the legacy Flask app, use `pytest` and place them under a separate Python test directory. Manually verify either UI against a disposable directory before replacing real content.

## Commit & Pull Request Guidelines

Use concise imperative commits, for example `Add recursive search tests` or `Fix replacement error handling`.

Pull requests should include a short description, the commands run, any manual UI checks performed, and screenshots or screen recordings when changing `static/index.html`.

## Security & Configuration Tips

This app reads and writes local files. Keep destructive actions behind explicit confirmation, preserve path validation, and test replacement changes only on disposable files.
Replacement flows must create `.replacer-backup` files before writing modified content.
