import AppKit
import FileReplaceCore
import SwiftUI

private enum ReplacerTheme {
    static let ink = Color(red: 0.12, green: 0.15, blue: 0.20)
    static let muted = Color(red: 0.45, green: 0.49, blue: 0.56)
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let panel = Color(red: 1.00, green: 0.99, blue: 0.96)
    static let blue = Color(red: 0.13, green: 0.36, blue: 0.92)
    static let teal = Color(red: 0.00, green: 0.66, blue: 0.58)
    static let amber = Color(red: 0.95, green: 0.61, blue: 0.18)
    static let border = Color.black.opacity(0.08)

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

private struct SearchOutcome: Sendable {
    var report: SearchReport?
    var errorMessage: String?
}

@MainActor
final class FileReplaceViewModel: ObservableObject {
    @Published var directoryURL: URL?
    @Published var directoryPathInput = ""
    @Published var namePattern = ""
    @Published var searchText = ""
    @Published var replacementText = ""
    @Published var recursive = false
    @Published var maxDepth = 5.0
    @Published var hits: [SearchHit] = []
    @Published var selectedHitIDs = Set<SearchHit.ID>()
    @Published var statusMessage = "Selecciona un directorio y define la búsqueda."
    @Published var isWorking = false
    @Published var lastReport: SearchReport?
    @Published var replacementLog: [String] = []

    @Published var previewHit: SearchHit?
    @Published var previewContent: String?
    @Published var previewError: String?
    @Published var isLoadingPreview = false
    private(set) var previewHighlightText = ""

    private let service = FileReplaceService()

    var selectedHits: [SearchHit] {
        hits.filter { selectedHitIDs.contains($0.id) }
    }

    var canSearch: Bool {
        directoryURL != nil && !searchText.isEmpty
    }

    var canReplace: Bool {
        !selectedHitIDs.isEmpty && !searchText.isEmpty && !isWorking
    }

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
            statusMessage = "Selección de carpeta cancelada o no disponible. Usa el campo de ruta."
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
        lastReport = nil
        replacementLog = []
        statusMessage = "Directorio: \(url.path). Escribe el texto a buscar y pulsa «Buscar coincidencias»."
    }

    func search() {
        let dir = directoryURL
        let pattern = namePattern
        let text = searchText
        let rec = recursive
        let depth = Int(maxDepth)
        let service = self.service

        isWorking = true
        replacementLog = []
        hits = []
        selectedHitIDs = []
        statusMessage = "Buscando…"

        Task {
            let outcome: SearchOutcome = await Task.detached(priority: .userInitiated) {
                do {
                    let report = try service.search(
                        directoryURL: dir,
                        namePattern: pattern,
                        searchText: text,
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

                var message = "\(report.hits.count) archivo(s) con coincidencias sobre \(report.filesScanned) revisado(s). Revisa y marca los archivos que quieras reemplazar."
                if !report.skippedFiles.isEmpty {
                    message += " \(report.skippedFiles.count) omitido(s) (binario, no UTF-8 o demasiado grande)."
                }
                if report.reachedResultLimit {
                    message += " Se alcanzó el límite de resultados; acota con un filtro de nombre o menos profundidad."
                }
                statusMessage = message
            } else {
                let detail = outcome.errorMessage ?? "Error desconocido en la búsqueda."
                hits = []
                selectedHitIDs = []
                lastReport = nil
                statusMessage = detail
            }

            isWorking = false
        }
    }

    func replaceSelected() {
        guard !selectedHits.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Confirmar reemplazo"
        alert.informativeText = "Se modificarán \(selectedHits.count) archivo(s). Antes de escribir, Replacer creará una copia .replacer-backup junto a cada archivo."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reemplazar")
        alert.addButton(withTitle: "Cancelar")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let targets = selectedHits
        let needle = searchText
        let replacement = replacementText
        let service = self.service

        isWorking = true
        replacementLog = []
        statusMessage = "Reemplazando en \(targets.count) archivo(s)…"

        Task {
            let lines: [String] = await Task.detached(priority: .userInitiated) {
                var out: [String] = []
                for hit in targets {
                    do {
                        let result = try service.replace(in: hit, searchText: needle, replacementText: replacement)
                        out.append("\(hit.relativePath): \(result.replacements) reemplazo(s). Backup: \(result.backupURL.lastPathComponent)")
                    } catch {
                        out.append("\(hit.relativePath): \(error.localizedDescription)")
                    }
                }
                return out
            }.value

            replacementLog = lines
            statusMessage = "Reemplazo finalizado en \(targets.count) archivo(s)."
            isWorking = false
        }
    }

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
    /// fuera del hilo principal. El texto a resaltar se congela al abrir la hoja,
    /// aunque el usuario siga editando el campo de búsqueda mientras está abierta.
    func openPreview(for hit: SearchHit) {
        previewHit = hit
        previewContent = nil
        previewError = nil
        previewHighlightText = searchText
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
        previewHighlightText = ""
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
                highlightText: viewModel.previewHighlightText,
                onRevealInFinder: { viewModel.revealInFinder(hit) },
                onClose: { viewModel.closePreview() }
            )
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
                                    onToggle: { viewModel.toggleSelection(for: hit) },
                                    onRevealInFinder: { viewModel.revealInFinder(hit) },
                                    onViewContent: { viewModel.openPreview(for: hit) }
                                )
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
            colors: [
                Color(red: 0.96, green: 0.98, blue: 1.0),
                Color(red: 0.93, green: 0.97, blue: 0.95)
            ],
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

            UpdatesButton()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.white.opacity(0.72))
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
            Label("\(viewModel.selectedHitIDs.count) de \(viewModel.hits.count) seleccionados", systemImage: "checklist")
                .font(.callout.weight(.semibold))
                .foregroundStyle(ReplacerTheme.ink)

            Spacer()

            Button("Seleccionar todo") {
                viewModel.selectAll()
            }

            Button("Limpiar selección") {
                viewModel.clearSelection()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.white.opacity(0.54))
    }
}

struct UpdatesButton: View {
    var body: some View {
        Button {
            UpdateCenter.presentUpdateOptions()
        } label: {
            Label("Actualizaciones", systemImage: "arrow.up.right.square")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help("Versión \(ReplacerVersion.current.description). Consultar releases privadas")
    }
}

struct SidebarView: View {
    @ObservedObject var viewModel: FileReplaceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                brandHeader

                ControlGroupBox(title: "Ubicación", icon: "folder.fill") {
                    Button {
                        viewModel.chooseDirectory()
                    } label: {
                        Label("Seleccionar directorio", systemImage: "folder.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftButtonStyle())

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

                    Text(viewModel.directoryURL?.path ?? "Sin directorio seleccionado")
                        .font(.caption)
                        .foregroundStyle(ReplacerTheme.muted)
                        .lineLimit(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.white.opacity(0.62))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                ControlGroupBox(title: "Búsqueda", icon: "text.viewfinder") {
                    LabeledInput(title: "Filtro de nombre (opcional)") {
                        NamePatternField(text: $viewModel.namePattern)
                    }

                    LabeledInput(title: "Texto a buscar") {
                        PromptTextEditor(
                            text: $viewModel.searchText,
                            prompt: "Cadena exacta que quieres localizar"
                        )
                        .frame(minHeight: 86)
                    }

                    LabeledInput(title: "Texto de reemplazo") {
                        PromptTextEditor(
                            text: $viewModel.replacementText,
                            prompt: "Nuevo texto que se escribirá"
                        )
                        .frame(minHeight: 86)
                    }

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
            .padding(22)
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 14) {
            AppGlyph(size: 70, cornerRadius: 17)
                .shadow(color: ReplacerTheme.teal.opacity(0.22), radius: 16, y: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text("Replacer")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(ReplacerTheme.ink)
                Text("Encuentra. Revisa. Sustituye.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(ReplacerTheme.muted)
            }
        }
        .padding(.bottom, 4)
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
                    .stroke(.white.opacity(0.75), lineWidth: 1)
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

            Text("Patrón glob sobre el nombre del archivo. Vacío = todos los archivos del alcance elegido.")
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
        .background(Color.white)
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

struct HitRow: View {
    let hit: SearchHit
    let isSelected: Bool
    let onToggle: () -> Void
    let onRevealInFinder: () -> Void
    let onViewContent: () -> Void

    var body: some View {
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
                            .background(Color(red: 0.96, green: 0.98, blue: 1.0))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 10) {
                Text("\(hit.count) coincidencia(s)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ReplacerTheme.blue)
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isSelected ? 0.96 : 0.78))
                .shadow(color: Color.black.opacity(isSelected ? 0.10 : 0.05), radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? ReplacerTheme.teal.opacity(0.55) : ReplacerTheme.border, lineWidth: isSelected ? 1.5 : 1)
        )
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
        .background(Color.white.opacity(0.76))
    }
}

/// Hoja de solo lectura que muestra el contenido íntegro de un `SearchHit` con las
/// coincidencias de `highlightText` resaltadas. No permite editar ni escribir el archivo:
/// cualquier cambio real pasa siempre por el flujo de reemplazo con confirmación y backup.
struct FileContentPreviewView: View {
    let hit: SearchHit
    let content: String?
    let errorMessage: String?
    let isLoading: Bool
    let highlightText: String
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
                ReadOnlyHighlightedTextView(content: content, highlightText: highlightText)
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

/// `NSTextView` de solo lectura que resalta cada aparición de `highlightText` en `content`.
/// Limita el resaltado a las primeras `maxHighlights` coincidencias para no penalizar
/// el render en archivos con miles de apariciones.
struct ReadOnlyHighlightedTextView: NSViewRepresentable {
    let content: String
    let highlightText: String
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
        // `content`/`highlightText` no cambian durante la vida de esta vista; evita recalcular
        // el resaltado (y perder la posición de scroll o la selección) en cada redibujado de SwiftUI.
        guard textView.string != content else { return }

        let attributed = NSMutableAttributedString(
            string: content,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
        )

        if !highlightText.isEmpty {
            let nsContent = content as NSString
            var searchRange = NSRange(location: 0, length: nsContent.length)
            var highlighted = 0

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
