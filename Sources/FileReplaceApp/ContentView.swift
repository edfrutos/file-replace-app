import AppKit
import Combine
import FileReplaceCore
import SwiftUI
import UniformTypeIdentifiers

/// Color que cambia según el modo de apariencia activo (claro u oscuro), sin
/// depender de colores con nombre en un asset catalog — necesario porque este
/// archivo se comparte, por symlink, entre el target de Xcode (App Store) y el
/// ejecutable SwiftPM (`swift run` / DMG), y solo el primero empaqueta un
/// asset catalog.
private extension Color {
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

enum ReplacerTheme {
    static let ink = Color(
        light: NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.20, alpha: 1),
        dark: NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.97, alpha: 1)
    )
    static let muted = Color(
        light: NSColor(calibratedRed: 0.45, green: 0.49, blue: 0.56, alpha: 1),
        dark: NSColor(calibratedRed: 0.64, green: 0.67, blue: 0.74, alpha: 1)
    )
    static let paper = Color(
        light: NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.92, alpha: 1),
        dark: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.12, alpha: 1)
    )
    static let panel = Color(
        light: NSColor(calibratedRed: 1.00, green: 0.99, blue: 0.96, alpha: 1),
        dark: NSColor(calibratedRed: 0.15, green: 0.16, blue: 0.19, alpha: 1)
    )
    static let blue = Color(
        light: NSColor(calibratedRed: 0.13, green: 0.36, blue: 0.92, alpha: 1),
        dark: NSColor(calibratedRed: 0.42, green: 0.60, blue: 1.00, alpha: 1)
    )
    static let teal = Color(
        light: NSColor(calibratedRed: 0.00, green: 0.66, blue: 0.58, alpha: 1),
        dark: NSColor(calibratedRed: 0.30, green: 0.82, blue: 0.72, alpha: 1)
    )
    static let amber = Color(
        light: NSColor(calibratedRed: 0.95, green: 0.61, blue: 0.18, alpha: 1),
        dark: NSColor(calibratedRed: 1.00, green: 0.73, blue: 0.35, alpha: 1)
    )
    static let border = Color(
        light: NSColor.black.withAlphaComponent(0.08),
        dark: NSColor.white.withAlphaComponent(0.14)
    )

    /// Sustituye los fondos "blancos" fijos que había sueltos por el archivo
    /// (tarjetas, cuadros de texto) por una superficie que se oscurece también.
    static let surface = Color(
        light: NSColor.white,
        dark: NSColor(calibratedRed: 0.18, green: 0.19, blue: 0.23, alpha: 1)
    )

    /// Fondo suave para fragmentos de vista previa de texto.
    static let tint = Color(
        light: NSColor(calibratedRed: 0.96, green: 0.98, blue: 1.0, alpha: 1),
        dark: NSColor(calibratedRed: 0.14, green: 0.18, blue: 0.24, alpha: 1)
    )

    static let sidebarGradientStart = Color(
        light: NSColor(calibratedRed: 0.96, green: 0.98, blue: 1.0, alpha: 1),
        dark: NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.14, alpha: 1)
    )
    static let sidebarGradientEnd = Color(
        light: NSColor(calibratedRed: 0.93, green: 0.97, blue: 0.95, alpha: 1),
        dark: NSColor(calibratedRed: 0.07, green: 0.11, blue: 0.10, alpha: 1)
    )

    static let accentGradient = LinearGradient(
        colors: [blue, teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Marca visual de la app dibujada en código (sin depender de recursos del bundle).
struct AppGlyph: View {
    var size: CGFloat
    var cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(ReplacerTheme.accentGradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: size * 0.44, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}

/// Par «buscar → reemplazar» tal como se edita en la barra lateral. El `id`
/// estable evita que SwiftUI recree los editores al añadir o quitar pares.
struct EditableRule: Identifiable, Equatable {
    let id: UUID
    var find: String
    var replace: String

    init(id: UUID = UUID(), find: String = "", replace: String = "") {
        self.id = id
        self.find = find
        self.replace = replace
    }

    var rule: ReplacementRule {
        ReplacementRule(find: find, replace: replace)
    }
}

/// Parámetros de una búsqueda, guardados para poder repetirla tal cual tras
/// un reemplazo aunque el usuario haya editado los campos entretanto.
private struct SearchQuery {
    var directoryURL: URL?
    var namePattern: String
    var rules: [ReplacementRule]
    var recursive: Bool
    var maxDepth: Int
}

private struct SearchOutcome: Sendable {
    var report: SearchReport?
    var errorMessage: String?
}

private let recipesDefaultsKey = "replacerRecipes"

@MainActor
final class FileReplaceViewModel: ObservableObject {
    @Published var directoryURL: URL?
    @Published var directoryPathInput = ""
    @Published var namePattern = ""
    @Published var rules: [EditableRule] = [EditableRule()]
    @Published var recursive = false
    @Published var maxDepth = 5.0
    @Published var hits: [SearchHit] = []
    @Published var selectedHitIDs = Set<SearchHit.ID>()
    /// Apariciones que el usuario ha desmarcado, por archivo. Lo que no está
    /// aquí se reemplaza.
    @Published var excludedOccurrences: [SearchHit.ID: Set<Int>] = [:]
    @Published var expandedHitIDs = Set<SearchHit.ID>()
    @Published var statusMessage = "Selecciona un directorio y define la búsqueda."
    @Published var isWorking = false
    @Published var lastReport: SearchReport?
    @Published var replacementLog: [String] = []
    @Published private(set) var recipes: [ReplacementRecipe] = []
    /// Reemplazos ya hechos, el más reciente primero (ver `ReplacementHistoryView.swift`).
    @Published var history: [ReplacementBatch] = []
    @Published var isShowingHistory = false
    private var lastQuery: SearchQuery?

    @Published var previewHit: SearchHit?
    @Published var previewContent: String?
    @Published var previewError: String?
    @Published var isLoadingPreview = false
    private(set) var previewHighlightTexts: [String] = []

    let service = FileReplaceService()
    let historyStore = ReplacementHistoryStore(fileURL: FileReplaceViewModel.historyFileURL)

    init() {
        loadRecipes()
        history = historyStore.load()
    }

    /// Reglas con texto de búsqueda, en el orden de la barra lateral.
    var activeRules: [ReplacementRule] {
        rules.map(\.rule).filter { !$0.find.isEmpty }
    }

    /// `true` si, tras buscar, el usuario ha cambiado algún texto a buscar: los
    /// resultados ya no corresponden y hay que volver a buscar antes de
    /// reemplazar. Cambiar solo los textos de reemplazo no invalida nada.
    var criteriaChanged: Bool {
        guard let lastQuery else { return false }
        return lastQuery.rules.map(\.find) != activeRules.map(\.find)
    }

    /// Reglas con las que se reemplazará: las buscadas, con el texto de
    /// reemplazo que haya ahora en la barra lateral.
    private var replaceRules: [ReplacementRule]? {
        guard lastQuery != nil, !criteriaChanged else { return nil }
        return activeRules
    }

    var selectedHits: [SearchHit] {
        hits.filter { selectedHitIDs.contains($0.id) && includedCount(for: $0) > 0 }
    }

    var canSearch: Bool {
        directoryURL != nil && !activeRules.isEmpty
    }

    var canReplace: Bool {
        !selectedHits.isEmpty && replaceRules != nil && !isWorking
    }

    func includedCount(for hit: SearchHit) -> Int {
        hit.count - (excludedOccurrences[hit.id]?.count ?? 0)
    }

    func excludedIDs(for hit: SearchHit) -> Set<Int> {
        excludedOccurrences[hit.id] ?? []
    }

    /// Texto que sustituirá a `occurrence` si se reemplaza ahora.
    func replacement(for occurrence: MatchOccurrence) -> String {
        let source = replaceRules ?? lastQuery?.rules ?? []
        return source.indices.contains(occurrence.ruleIndex) ? source[occurrence.ruleIndex].replace : ""
    }

    // MARK: - Pares buscar → reemplazar

    func addRule() {
        rules.append(EditableRule())
    }

    func removeRule(_ id: EditableRule.ID) {
        if rules.count > 1 {
            rules.removeAll { $0.id == id }
        } else {
            rules = [EditableRule()]
        }
    }

    /// Bindings por `id` en lugar de por índice: al quitar un par mientras su
    /// editor tiene el foco, un binding por índice apuntaría fuera del array.
    func findBinding(for id: EditableRule.ID) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.rules.first { $0.id == id }?.find ?? "" },
            set: { [weak self] value in
                guard let self, let index = self.rules.firstIndex(where: { $0.id == id }) else { return }
                self.rules[index].find = value
            }
        )
    }

    func replaceBinding(for id: EditableRule.ID) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.rules.first { $0.id == id }?.replace ?? "" },
            set: { [weak self] value in
                guard let self, let index = self.rules.firstIndex(where: { $0.id == id }) else { return }
                self.rules[index].replace = value
            }
        )
    }

    // MARK: - Recetas

    func applyRecipe(_ recipe: ReplacementRecipe) {
        rules = recipe.rules.isEmpty ? [EditableRule()] : recipe.rules.map { EditableRule(find: $0.find, replace: $0.replace) }
        statusMessage = "Receta «\(recipe.name)» cargada: \(recipe.rules.count) par(es). Pulsa «Buscar coincidencias»."
    }

    func saveCurrentRulesAsRecipe() {
        let current = activeRules
        guard !current.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Guardar receta"
        alert.informativeText = "Guarda estos \(current.count) par(es) para reutilizarlos más adelante."
        alert.addButton(withTitle: "Guardar")
        alert.addButton(withTitle: "Cancelar")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "Nombre de la receta"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            statusMessage = "La receta necesita un nombre."
            return
        }

        if let index = recipes.firstIndex(where: { $0.name == name }) {
            recipes[index].rules = current
        } else {
            recipes.append(ReplacementRecipe(name: name, rules: current))
            recipes.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        storeRecipes()
        statusMessage = "Receta «\(name)» guardada."
    }

    func deleteRecipe(_ recipe: ReplacementRecipe) {
        recipes.removeAll { $0.id == recipe.id }
        storeRecipes()
        statusMessage = "Receta «\(recipe.name)» eliminada."
    }

    /// Carga pares desde un CSV/TSV (primera columna buscar, segunda reemplazar)
    /// y sustituye los de la barra lateral.
    func importRulesFromCSV() {
        NSApp.activate()

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.commaSeparatedText, .tabSeparatedText, .plainText]
        panel.prompt = "Importar"
        panel.message = "Elige un CSV con dos columnas: texto a buscar y texto de reemplazo"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            statusMessage = "No se pudo leer \(url.lastPathComponent)."
            return
        }

        let imported = RuleListParser.parse(text)
        guard !imported.isEmpty else {
            statusMessage = "\(url.lastPathComponent) no contiene pares válidos (columna 1: buscar, columna 2: reemplazar)."
            return
        }

        rules = imported.map { EditableRule(find: $0.find, replace: $0.replace) }
        statusMessage = "Importados \(imported.count) par(es) desde \(url.lastPathComponent). Pulsa «Buscar coincidencias»."
    }

    private func loadRecipes() {
        guard let data = UserDefaults.standard.data(forKey: recipesDefaultsKey),
              let stored = try? JSONDecoder().decode([ReplacementRecipe].self, from: data) else { return }
        recipes = stored
    }

    private func storeRecipes() {
        guard let data = try? JSONEncoder().encode(recipes) else { return }
        UserDefaults.standard.set(data, forKey: recipesDefaultsKey)
    }

    // MARK: - Directorio

    func chooseDirectory() {
        // Al ejecutar como binario de SwiftPM (`swift run`) la app puede no estar
        // activa; sin esto el panel puede abrirse detrás de la ventana.
        NSApp.activate()

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Seleccionar"
        panel.message = "Elige la carpeta donde buscar"

        guard panel.runModal() == .OK, let url = panel.url else {
            // Con una carpeta ya elegida, cancelar no cambia nada: se conserva
            // el estado de la búsqueda en curso.
            if directoryURL == nil {
                #if APPSTORE_BUILD
                statusMessage = "Selección de carpeta cancelada. Pulsa «Seleccionar directorio» para elegir dónde buscar."
                #else
                statusMessage = "Selección de carpeta cancelada o no disponible. Usa el campo de ruta."
                #endif
            }
            return
        }
        applyDirectory(url)
    }

    /// Alternativa al panel nativo: fija el directorio a partir de una ruta escrita
    /// o pegada. Imprescindible cuando el panel no está disponible (`swift run`).
    func applyTypedDirectory() {
        let trimmed = directoryPathInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "Escribe una ruta de directorio en el campo."
            return
        }

        let expanded = (trimmed as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            statusMessage = "La ruta no existe o no es un directorio: \(expanded)"
            return
        }

        applyDirectory(url)
    }

    private func applyDirectory(_ url: URL) {
        directoryURL = url
        directoryPathInput = url.path
        hits = []
        selectedHitIDs = []
        excludedOccurrences = [:]
        expandedHitIDs = []
        lastReport = nil
        lastQuery = nil
        replacementLog = []
        statusMessage = "Directorio: \(url.path). Escribe el texto a buscar y pulsa «Buscar coincidencias»."
    }

    // MARK: - Búsqueda y reemplazo

    func search() {
        let query = SearchQuery(
            directoryURL: directoryURL,
            namePattern: namePattern,
            rules: activeRules,
            recursive: recursive,
            maxDepth: Int(maxDepth)
        )
        lastQuery = query
        replacementLog = []
        runSearch(query, statusPrefix: nil)
    }

    /// Ejecuta `query` y sustituye la lista de resultados. `statusPrefix` se
    /// antepone al resumen (lo usa el refresco tras un reemplazo para no perder
    /// el mensaje de «Reemplazo finalizado…»).
    /// Repite la última búsqueda, si la hay, para que la lista refleje cambios
    /// hechos en los archivos (por ejemplo, tras restaurar desde el historial).
    func refreshResults(statusPrefix: String) {
        if let lastQuery {
            runSearch(lastQuery, statusPrefix: statusPrefix)
        } else {
            statusMessage = statusPrefix
        }
    }

    private func runSearch(_ query: SearchQuery, statusPrefix: String?) {
        let dir = query.directoryURL
        let pattern = query.namePattern
        let searchRules = query.rules
        let rec = query.recursive
        let depth = query.maxDepth
        let service = self.service

        isWorking = true
        hits = []
        selectedHitIDs = []
        excludedOccurrences = [:]
        expandedHitIDs = []
        statusMessage = statusPrefix.map { "\($0) Actualizando resultados…" } ?? "Buscando…"

        Task {
            let outcome: SearchOutcome = await Task.detached(priority: .userInitiated) {
                do {
                    let report = try service.search(
                        directoryURL: dir,
                        namePattern: pattern,
                        rules: searchRules,
                        recursive: rec,
                        maxDepth: depth
                    )
                    return SearchOutcome(report: report, errorMessage: nil)
                } catch {
                    return SearchOutcome(report: nil, errorMessage: error.localizedDescription)
                }
            }.value

            if let report = outcome.report {
                lastReport = report
                hits = report.hits
                selectedHitIDs = []

                let occurrences = report.hits.reduce(0) { $0 + $1.count }
                var message = report.hits.isEmpty
                    ? "Ninguna coincidencia en \(report.filesScanned) archivo(s) revisado(s)."
                    : "\(occurrences) coincidencia(s) en \(report.hits.count) archivo(s) sobre \(report.filesScanned) revisado(s). Revisa y marca lo que quieras reemplazar."
                if !report.skippedFiles.isEmpty {
                    message += " \(report.skippedFiles.count) omitido(s) (binario, no UTF-8 o demasiado grande)."
                }
                if report.reachedResultLimit {
                    message += " Se alcanzó el límite de resultados; acota con un filtro de nombre o menos profundidad."
                }
                statusMessage = statusPrefix.map { "\($0) \(message)" } ?? message
            } else {
                let detail = outcome.errorMessage ?? "Error desconocido en la búsqueda."
                hits = []
                selectedHitIDs = []
                lastReport = nil
                statusMessage = statusPrefix.map { "\($0) \(detail)" } ?? detail
            }

            isWorking = false
        }
    }

    func replaceSelected() {
        guard let replaceRules = self.replaceRules else { return }
        let targets = selectedHits
        guard !targets.isEmpty else { return }

        let total = targets.reduce(0) { $0 + includedCount(for: $1) }
        let alert = NSAlert()
        alert.messageText = "Confirmar reemplazo"
        alert.informativeText = "Se reemplazarán \(total) coincidencia(s) en \(targets.count) archivo(s). Antes de escribir, Replacer creará una copia .replacer-backup junto a cada archivo."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reemplazar")
        alert.addButton(withTitle: "Cancelar")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let exclusions = excludedOccurrences
        let service = self.service

        isWorking = true
        replacementLog = []
        statusMessage = "Reemplazando en \(targets.count) archivo(s)…"

        Task {
            let (lines, entries): ([String], [ReplacementBatch.Entry]) = await Task.detached(priority: .userInitiated) {
                var out: [String] = []
                var entries: [ReplacementBatch.Entry] = []
                for hit in targets {
                    do {
                        let result = try service.replace(
                            in: hit,
                            rules: replaceRules,
                            excludingOccurrences: exclusions[hit.id] ?? []
                        )
                        out.append("\(hit.relativePath): \(result.replacements) reemplazo(s). Backup: \(result.backupURL.lastPathComponent)")
                        if let entry = ReplacementBatch.Entry(result: result) {
                            entries.append(entry)
                        }
                    } catch {
                        out.append("\(hit.relativePath): \(error.localizedDescription)")
                    }
                }
                return (out, entries)
            }.value

            replacementLog = lines
            if let directoryURL = lastQuery?.directoryURL, !entries.isEmpty {
                recordBatch(directoryURL: directoryURL, rules: replaceRules, entries: entries)
            }
            let summary = "Reemplazo finalizado en \(targets.count) archivo(s)."
            // Repite la búsqueda —con los textos de reemplazo usados— para que
            // la lista refleje el contenido ya modificado.
            if var query = lastQuery {
                query.rules = replaceRules
                lastQuery = query
                runSearch(query, statusPrefix: summary)
            } else {
                statusMessage = summary
                isWorking = false
            }
        }
    }

    // MARK: - Selección

    func toggleSelection(for hit: SearchHit) {
        if selectedHitIDs.contains(hit.id) {
            selectedHitIDs.remove(hit.id)
        } else {
            selectedHitIDs.insert(hit.id)
        }
    }

    func selectAll() {
        selectedHitIDs = Set(hits.map(\.id))
    }

    func clearSelection() {
        selectedHitIDs = []
    }

    func toggleExpanded(_ hit: SearchHit) {
        if expandedHitIDs.contains(hit.id) {
            expandedHitIDs.remove(hit.id)
        } else {
            expandedHitIDs.insert(hit.id)
        }
    }

    /// Marca o desmarca una aparición. Marcar una aparición de un archivo no
    /// seleccionado lo selecciona, para que el cambio tenga efecto.
    func toggleOccurrence(_ occurrenceID: Int, in hit: SearchHit) {
        var excluded = excludedOccurrences[hit.id] ?? []
        if excluded.contains(occurrenceID) {
            excluded.remove(occurrenceID)
            selectedHitIDs.insert(hit.id)
        } else {
            excluded.insert(occurrenceID)
        }
        excludedOccurrences[hit.id] = excluded.isEmpty ? nil : excluded
    }

    func includeAllOccurrences(in hit: SearchHit) {
        excludedOccurrences[hit.id] = nil
        selectedHitIDs.insert(hit.id)
    }

    func excludeAllOccurrences(in hit: SearchHit) {
        excludedOccurrences[hit.id] = Set(hit.occurrences.map(\.id))
    }

    /// Descarta los resultados de la búsqueda en curso y vuelve al estado
    /// vacío, conservando el directorio y los pares buscar → reemplazar para
    /// poder relanzarla.
    func clearResults() {
        closePreview()
        hits = []
        selectedHitIDs = []
        excludedOccurrences = [:]
        expandedHitIDs = []
        lastReport = nil
        lastQuery = nil
        replacementLog = []
        if let directoryURL {
            statusMessage = "Directorio: \(directoryURL.path). Escribe el texto a buscar y pulsa «Buscar coincidencias»."
        } else {
            statusMessage = "Selecciona un directorio y define la búsqueda."
        }
    }

    /// Trae Finder a primer plano con `hit` ya seleccionado en su carpeta contenedora.
    /// No modifica ni crea nada en el filesystem.
    func revealInFinder(_ hit: SearchHit) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: hit.fileURL.path, isDirectory: &isDirectory) else {
            statusMessage = "No se pudo localizar en Finder: el archivo ya no existe en \(hit.fileURL.path)."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([hit.fileURL])
    }

    /// Abre la hoja de previsualización y carga el contenido completo del archivo
    /// fuera del hilo principal. Los textos a resaltar son los de la búsqueda.
    func openPreview(for hit: SearchHit) {
        previewHit = hit
        previewContent = nil
        previewError = nil
        previewHighlightTexts = lastQuery?.rules.map(\.find) ?? []
        isLoadingPreview = true

        let fileURL = hit.fileURL
        let service = self.service

        Task {
            do {
                let content = try await Task.detached(priority: .userInitiated) {
                    try service.readFullContent(at: fileURL)
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
        previewHighlightTexts = []
    }
}

struct ContentView: View {
    @StateObject private var viewModel = FileReplaceViewModel()

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(viewModel: viewModel)
                .frame(width: 400)
                .frame(maxHeight: .infinity)
                .background(sidebarBackground)

            Divider()

            detailPane
                .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 860, minHeight: 620)
        .sheet(item: $viewModel.previewHit) { hit in
            FileContentPreviewView(
                hit: hit,
                content: viewModel.previewContent,
                errorMessage: viewModel.previewError,
                isLoading: viewModel.isLoadingPreview,
                highlightTexts: viewModel.previewHighlightTexts,
                onRevealInFinder: { viewModel.revealInFinder(hit) },
                onClose: { viewModel.closePreview() }
            )
        }
        .sheet(isPresented: $viewModel.isShowingHistory) {
            ReplacementHistoryView(viewModel: viewModel)
        }
    }

    private var detailPane: some View {
        ZStack {
            ReplacerTheme.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header

                if viewModel.hits.isEmpty {
                    emptyState
                } else {
                    resultsToolbar
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.hits) { hit in
                                HitRow(
                                    hit: hit,
                                    isSelected: viewModel.selectedHitIDs.contains(hit.id),
                                    includedCount: viewModel.includedCount(for: hit),
                                    isExpanded: viewModel.expandedHitIDs.contains(hit.id),
                                    onToggle: { viewModel.toggleSelection(for: hit) },
                                    onToggleExpanded: { viewModel.toggleExpanded(hit) },
                                    onRevealInFinder: { viewModel.revealInFinder(hit) },
                                    onViewContent: { viewModel.openPreview(for: hit) }
                                ) {
                                    OccurrenceList(
                                        hit: hit,
                                        excluded: viewModel.excludedIDs(for: hit),
                                        replacement: { viewModel.replacement(for: $0) },
                                        onToggle: { viewModel.toggleOccurrence($0, in: hit) },
                                        onIncludeAll: { viewModel.includeAllOccurrences(in: hit) },
                                        onExcludeAll: { viewModel.excludeAllOccurrences(in: hit) }
                                    )
                                }
                            }
                        }
                        .padding(22)
                    }
                }

                if !viewModel.replacementLog.isEmpty {
                    ReplacementLogView(lines: viewModel.replacementLog)
                }
            }
        }
    }

    private var sidebarBackground: some View {
        LinearGradient(
            colors: [ReplacerTheme.sidebarGradientStart, ReplacerTheme.sidebarGradientEnd],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 16) {
            AppGlyph(size: 54, cornerRadius: 13)
                .shadow(color: ReplacerTheme.blue.opacity(0.25), radius: 14, y: 7)

            VStack(alignment: .leading, spacing: 5) {
                Text("Búsqueda y reemplazo en archivos")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ReplacerTheme.ink)
                Text(viewModel.statusMessage)
                    .font(.callout)
                    .foregroundStyle(ReplacerTheme.muted)
                    .lineLimit(2)
            }

            Spacer()

            if viewModel.isWorking {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                viewModel.isShowingHistory = true
            } label: {
                Label("Historial", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(.bordered)
            .help("Reemplazos anteriores; desde aquí puedes deshacerlos")

            UpdatesButton()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(ReplacerTheme.surface.opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ReplacerTheme.border)
                .frame(height: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(ReplacerTheme.accentGradient.opacity(0.16))
                    .frame(width: 126, height: 126)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(ReplacerTheme.accentGradient)
            }

            VStack(spacing: 8) {
                Text("Listo para encontrar cambios")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(ReplacerTheme.ink)
                Text("Elige un directorio, ajusta el filtro de nombre opcional y revisa cada coincidencia antes de reemplazar.")
                    .font(.title3)
                    .foregroundStyle(ReplacerTheme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private var resultsToolbar: some View {
        HStack {
            if viewModel.criteriaChanged {
                Label("Has cambiado el texto a buscar: vuelve a buscar para poder reemplazar", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ReplacerTheme.amber)
            } else {
                Label("\(viewModel.selectedHitIDs.count) de \(viewModel.hits.count) seleccionados", systemImage: "checklist")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ReplacerTheme.ink)
            }

            Spacer()

            Button("Seleccionar todo") {
                viewModel.selectAll()
            }
            .disabled(viewModel.selectedHitIDs.count == viewModel.hits.count)

            Button("Deseleccionar todo") {
                viewModel.clearSelection()
            }
            .disabled(viewModel.selectedHitIDs.isEmpty)

            Button(role: .destructive) {
                viewModel.clearResults()
            } label: {
                Label("Limpiar resultados", systemImage: "xmark.circle")
            }
            .disabled(viewModel.isWorking)
            .help("Descarta los resultados de esta búsqueda")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(ReplacerTheme.surface.opacity(0.54))
    }
}

struct UpdatesButton: View {
    var body: some View {
        #if APPSTORE_BUILD
        // La App Store gestiona las actualizaciones; no se ofrece un enlace externo.
        EmptyView()
        #else
        Button {
            UpdateCenter.presentUpdateOptions()
        } label: {
            Label("Actualizaciones", systemImage: "arrow.up.right.square")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help("Versión \(ReplacerVersion.current.description). Consultar releases privadas")
        #endif
    }
}

struct SidebarView: View {
    @ObservedObject var viewModel: FileReplaceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                brandHeader

                ControlGroupBox(title: "Ubicación", icon: "folder.fill") {
                    Button {
                        viewModel.chooseDirectory()
                    } label: {
                        Label("Seleccionar directorio", systemImage: "folder.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftButtonStyle())

                    #if !APPSTORE_BUILD
                    // El App Sandbox solo concede acceso a rutas elegidas mediante
                    // NSOpenPanel; una ruta escrita a mano no tiene ese permiso, así
                    // que este atajo se omite en el build de App Store.
                    HStack(spacing: 8) {
                        TextField("~/ruta/al/proyecto", text: $viewModel.directoryPathInput)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                            .font(.callout)
                            .onSubmit { viewModel.applyTypedDirectory() }

                        Button("Usar") {
                            viewModel.applyTypedDirectory()
                        }
                        .buttonStyle(SoftButtonStyle())
                    }

                    Text("Escribe o pega una ruta y pulsa «Usar» (o Intro). También puedes usar el botón de arriba.")
                        .font(.caption2)
                        .foregroundStyle(ReplacerTheme.muted)
                    #endif

                    Text(viewModel.directoryURL?.path ?? "Sin directorio seleccionado")
                        .font(.caption)
                        .foregroundStyle(ReplacerTheme.muted)
                        .lineLimit(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(ReplacerTheme.surface.opacity(0.62))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                ControlGroupBox(title: "Búsqueda", icon: "text.viewfinder") {
                    LabeledInput(title: "Filtro de nombre (opcional)") {
                        NamePatternField(text: $viewModel.namePattern)
                    }

                    RulesEditor(viewModel: viewModel)

                    Toggle("Buscar en subdirectorios", isOn: $viewModel.recursive)
                        .toggleStyle(.switch)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Profundidad")
                            Spacer()
                            Text("\(Int(viewModel.maxDepth)) niveles")
                                .foregroundStyle(ReplacerTheme.blue)
                                .fontWeight(.semibold)
                        }
                        .font(.caption)

                        Slider(value: $viewModel.maxDepth, in: 1...10, step: 1)
                            .tint(ReplacerTheme.blue)
                    }
                    .opacity(viewModel.recursive ? 1 : 0.45)
                    .disabled(!viewModel.recursive)
                }

                ControlGroupBox(title: "Acciones", icon: "bolt.fill") {
                    Button {
                        viewModel.search()
                    } label: {
                        Label("Buscar coincidencias", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!viewModel.canSearch || viewModel.isWorking)

                    Button(role: .destructive) {
                        viewModel.replaceSelected()
                    } label: {
                        Label("Reemplazar seleccionados", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftButtonStyle(tint: ReplacerTheme.amber))
                    .disabled(!viewModel.canReplace)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 14) {
            AppGlyph(size: 54, cornerRadius: 13)
                .shadow(color: ReplacerTheme.teal.opacity(0.22), radius: 16, y: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text("Replacer")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(ReplacerTheme.ink)
                Text("Encuentra. Revisa. Sustituye.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(ReplacerTheme.muted)
            }
        }
    }
}

struct ControlGroupBox<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(ReplacerTheme.ink)

            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ReplacerTheme.panel.opacity(0.92))
                    .shadow(color: Color.black.opacity(0.07), radius: 18, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ReplacerTheme.surface.opacity(0.75), lineWidth: 1)
            )
        }
    }
}

struct LabeledInput<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(ReplacerTheme.muted)
            content
        }
    }
}

struct NamePatternField: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("*.txt, config*, .env*", text: $text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
                .font(.callout)

            Text("Patrón glob sobre el nombre. Vacío = todos los archivos.")
                .font(.caption2)
                .foregroundStyle(ReplacerTheme.muted)
        }
    }
}

struct PromptTextEditor: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlainNSTextEditor(text: $text)

            if text.isEmpty {
                Text(prompt)
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
        }
        .background(ReplacerTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(ReplacerTheme.border, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}

/// Editor multilínea sobre `NSTextView` con TODA la sustitución tipográfica
/// desactivada (comillas curvas, guiones largos, reemplazo de texto, autocorrección).
/// Imprescindible para una herramienta de búsqueda/reemplazo de cadena exacta.
struct PlainNSTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.drawsBackground = false
        textView.string = text
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .background(ReplacerTheme.accentGradient)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .shadow(color: ReplacerTheme.blue.opacity(isEnabled ? 0.28 : 0), radius: 12, y: 6)
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.42)
    }
}

struct SoftButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var tint: Color = ReplacerTheme.blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.vertical, 11)
            .background(tint.opacity(configuration.isPressed ? 0.18 : 0.10))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.42)
    }
}

struct HitRow<Occurrences: View>: View {
    let hit: SearchHit
    let isSelected: Bool
    let includedCount: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    let onToggleExpanded: () -> Void
    let onRevealInFinder: () -> Void
    let onViewContent: () -> Void
    @ViewBuilder let occurrences: () -> Occurrences

    private var countLabel: String {
        includedCount == hit.count
            ? "\(hit.count) coincidencia(s)"
            : "\(includedCount) de \(hit.count) coincidencia(s)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summary

            Button(action: onToggleExpanded) {
                Label(
                    isExpanded ? "Ocultar coincidencias" : "Revisar coincidencias una a una",
                    systemImage: isExpanded ? "chevron.down" : "chevron.right"
                )
                .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(ReplacerTheme.blue)

            if isExpanded {
                occurrences()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ReplacerTheme.surface.opacity(isSelected ? 0.96 : 0.78))
                .shadow(color: Color.black.opacity(isSelected ? 0.10 : 0.05), radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? ReplacerTheme.teal.opacity(0.55) : ReplacerTheme.border, lineWidth: isSelected ? 1.5 : 1)
        )
    }

    private var summary: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? ReplacerTheme.teal : ReplacerTheme.muted.opacity(0.6))

                    VStack(alignment: .leading, spacing: 9) {
                        Text(hit.relativePath)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(ReplacerTheme.ink)
                            .lineLimit(2)

                        Text(hit.fileURL.path)
                            .font(.caption)
                            .foregroundStyle(ReplacerTheme.muted)
                            .lineLimit(1)

                        Text(hit.preview)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(ReplacerTheme.ink.opacity(0.86))
                            .lineLimit(4)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ReplacerTheme.tint)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 10) {
                Text(countLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(includedCount == hit.count ? ReplacerTheme.blue : ReplacerTheme.amber)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(ReplacerTheme.blue.opacity(0.10))
                    .clipShape(Capsule())

                HStack(spacing: 6) {
                    Button(action: onRevealInFinder) {
                        Image(systemName: "folder")
                    }
                    .help("Mostrar en Finder")

                    Button(action: onViewContent) {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .help("Ver contenido completo")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(ReplacerTheme.muted)
            }
        }
    }
}

struct ReplacementLogView: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Resultado", systemImage: "checkmark.seal.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(ReplacerTheme.teal)

            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(ReplacerTheme.muted)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReplacerTheme.surface.opacity(0.76))
    }
}

/// Hoja de solo lectura que muestra el contenido íntegro de un `SearchHit` con las
/// coincidencias de `highlightTexts` resaltadas. No permite editar ni escribir el archivo:
/// cualquier cambio real pasa siempre por el flujo de reemplazo con confirmación y backup.
struct FileContentPreviewView: View {
    let hit: SearchHit
    let content: String?
    let errorMessage: String?
    let isLoading: Bool
    let highlightTexts: [String]
    let onRevealInFinder: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            contentBody
            Divider()
            footer
        }
        .frame(minWidth: 640, idealWidth: 780, minHeight: 480, idealHeight: 620)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(hit.relativePath)
                    .font(.headline.weight(.bold))
                    .lineLimit(2)

                Spacer()

                Text("\(hit.count) coincidencia(s)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ReplacerTheme.blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(ReplacerTheme.blue.opacity(0.10))
                    .clipShape(Capsule())
            }

            Text(hit.fileURL.path)
                .font(.caption)
                .foregroundStyle(ReplacerTheme.muted)
                .textSelection(.enabled)
                .lineLimit(2)
        }
        .padding(18)
    }

    @ViewBuilder
    private var contentBody: some View {
        Group {
            if isLoading {
                ProgressView("Cargando contenido…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(ReplacerTheme.amber)
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(ReplacerTheme.ink)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 480)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else if let content {
                ReadOnlyHighlightedTextView(content: content, highlightTexts: highlightTexts)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Button("Mostrar en Finder", action: onRevealInFinder)
                .buttonStyle(SoftButtonStyle())

            Spacer()

            Button("Cerrar", action: onClose)
                .buttonStyle(SoftButtonStyle())
        }
        .padding(18)
    }
}

/// `NSTextView` de solo lectura que resalta cada aparición de `highlightTexts` en `content`.
/// Limita el resaltado a las primeras `maxHighlights` coincidencias para no penalizar
/// el render en archivos con miles de apariciones.
struct ReadOnlyHighlightedTextView: NSViewRepresentable {
    let content: String
    let highlightTexts: [String]
    let maxHighlights = 500

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        apply(to: textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        apply(to: textView)
    }

    private func apply(to textView: NSTextView) {
        // `content`/`highlightTexts` no cambian durante la vida de esta vista; evita recalcular
        // el resaltado (y perder la posición de scroll o la selección) en cada redibujado de SwiftUI.
        guard textView.string != content else { return }

        let attributed = NSMutableAttributedString(
            string: content,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
        )

        let nsContent = content as NSString
        var highlighted = 0

        for highlightText in highlightTexts where !highlightText.isEmpty {
            var searchRange = NSRange(location: 0, length: nsContent.length)

            while highlighted < maxHighlights {
                let found = nsContent.range(of: highlightText, options: [], range: searchRange)
                guard found.location != NSNotFound else { break }

                attributed.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.55), range: found)
                highlighted += 1

                let nextLocation = found.location + found.length
                guard nextLocation < nsContent.length else { break }
                searchRange = NSRange(location: nextLocation, length: nsContent.length - nextLocation)
            }
        }

        textView.textStorage?.setAttributedString(attributed)
    }
}
