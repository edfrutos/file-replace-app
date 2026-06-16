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

@MainActor
final class FileReplaceViewModel: ObservableObject {
    private static let maxListedFiles = 500

    @Published var directoryURL: URL?
    @Published var filename = ""
    @Published var availableFiles: [String] = []
    @Published var searchText = ""
    @Published var replacementText = ""
    @Published var recursive = false {
        didSet {
            reloadAvailableFiles()
        }
    }
    @Published var maxDepth = 5.0
    @Published var hits: [SearchHit] = []
    @Published var selectedHitIDs = Set<SearchHit.ID>()
    @Published var statusMessage = "Selecciona un directorio y define la búsqueda."
    @Published var isWorking = false
    @Published var lastReport: SearchReport?
    @Published var replacementLog: [String] = []

    private let service = FileReplaceService()

    var selectedHits: [SearchHit] {
        hits.filter { selectedHitIDs.contains($0.id) }
    }

    var canSearch: Bool {
        directoryURL != nil && !filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !searchText.isEmpty
    }

    var canReplace: Bool {
        !selectedHitIDs.isEmpty && !searchText.isEmpty && !isWorking
    }

    func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Seleccionar"

        if panel.runModal() == .OK {
            directoryURL = panel.url
            reloadAvailableFiles()
            statusMessage = "Directorio seleccionado: \(panel.url?.path ?? "")"
        }
    }

    func reloadAvailableFiles() {
        guard let directoryURL else {
            availableFiles = []
            filename = ""
            return
        }

        do {
            availableFiles = try listCandidateFiles(in: directoryURL, recursive: recursive)

            if !availableFiles.contains(filename) {
                filename = availableFiles.first ?? ""
            }
        } catch {
            availableFiles = []
            filename = ""
            statusMessage = "No se pudo leer el listado de archivos del directorio."
        }
    }

    private func listCandidateFiles(in directoryURL: URL, recursive: Bool) throws -> [String] {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .isHiddenKey]
        let urls: [URL]

        if recursive {
            guard let enumerator = FileManager.default.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return []
            }

            var collectedURLs: [URL] = []
            for case let url as URL in enumerator {
                collectedURLs.append(url)

                if collectedURLs.count >= Self.maxListedFiles {
                    break
                }
            }

            urls = collectedURLs
        } else {
            urls = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )
        }

        let filenames = urls.compactMap { url -> String? in
            guard
                let values = try? url.resourceValues(forKeys: resourceKeys),
                values.isRegularFile == true,
                values.isHidden != true,
                isLikelyEditableTextFile(url)
            else {
                return nil
            }

            return url.lastPathComponent
        }

        return Array(Set(filenames))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func isLikelyEditableTextFile(_ url: URL) -> Bool {
        let blockedExtensions: Set<String> = [
            "app", "bin", "bmp", "class", "dmg", "doc", "docx", "dylib", "exe",
            "gif", "heic", "icns", "ico", "jar", "jpeg", "jpg", "mov", "mp3",
            "mp4", "pdf", "pkg", "png", "pyc", "so", "sqlite", "ttf", "webp",
            "woff", "woff2", "xls", "xlsx", "zip"
        ]

        let ext = url.pathExtension.lowercased()
        return !blockedExtensions.contains(ext)
    }

    func search() {
        isWorking = true
        replacementLog = []

        do {
            let report = try service.search(
                directoryURL: directoryURL,
                filename: filename,
                searchText: searchText,
                recursive: recursive,
                maxDepth: Int(maxDepth)
            )

            lastReport = report
            hits = report.hits
            selectedHitIDs = Set(report.hits.map(\.id))
            statusMessage = "\(report.hits.count) archivo(s) con coincidencias. \(report.filesScanned) archivo(s) revisado(s)."
        } catch {
            hits = []
            selectedHitIDs = []
            lastReport = nil
            statusMessage = error.localizedDescription
        }

        isWorking = false
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

        isWorking = true
        replacementLog = []

        for hit in selectedHits {
            do {
                let result = try service.replace(
                    in: hit,
                    searchText: searchText,
                    replacementText: replacementText
                )
                replacementLog.append("\(hit.relativePath): \(result.replacements) reemplazo(s). Backup: \(result.backupURL.lastPathComponent)")
            } catch {
                replacementLog.append("\(hit.relativePath): \(error.localizedDescription)")
            }
        }

        statusMessage = "Reemplazo finalizado en \(selectedHits.count) archivo(s)."
        isWorking = false
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
}

struct ContentView: View {
    @StateObject private var viewModel = FileReplaceViewModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationTitle("Replacer")
                .frame(minWidth: 380)
                .background(sidebarBackground)
        } detail: {
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
                                        onToggle: { viewModel.toggleSelection(for: hit) }
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
            Image("AppIconPreview", bundle: .module)
                .resizable()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
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
                Text("Elige un directorio, selecciona un archivo del listado y revisa cada coincidencia antes de reemplazar.")
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
                    LabeledInput(title: "Archivo del directorio") {
                        FilePickerMenu(
                            files: viewModel.availableFiles,
                            selection: $viewModel.filename,
                            hasDirectory: viewModel.directoryURL != nil
                        )
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
            Image("AppIconPreview", bundle: .module)
                .resizable()
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
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

struct InputChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(ReplacerTheme.border, lineWidth: 1)
            )
    }
}

struct FilePickerMenu: View {
    let files: [String]
    @Binding var selection: String
    let hasDirectory: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                if files.isEmpty {
                    Text(hasDirectory ? "No hay archivos en este directorio" : "Selecciona primero un directorio")
                } else {
                    ForEach(files, id: \.self) { file in
                        Button {
                            selection = file
                        } label: {
                            if selection == file {
                                Label(file, systemImage: "checkmark")
                            } else {
                                Text(file)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: files.isEmpty ? "doc.badge.questionmark" : "doc.text")
                        .foregroundStyle(files.isEmpty ? ReplacerTheme.muted : ReplacerTheme.blue)

                    Text(selectionLabel)
                        .foregroundStyle(files.isEmpty ? ReplacerTheme.muted : ReplacerTheme.ink)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ReplacerTheme.muted)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(ReplacerTheme.border, lineWidth: 1)
                )
            }
            .disabled(files.isEmpty)

            Text(helperText)
                .font(.caption2)
                .foregroundStyle(ReplacerTheme.muted)
        }
    }

    private var selectionLabel: String {
        if !selection.isEmpty {
            return selection
        }

        return hasDirectory ? "Sin archivos disponibles" : "Selecciona un directorio"
    }

    private var helperText: String {
        if !hasDirectory {
            return "El listado aparecerá después de elegir una carpeta."
        }

        if files.isEmpty {
            return "Este selector muestra archivos directos del directorio seleccionado."
        }

        return "\(files.count) archivo(s) de texto disponibles para este modo de búsqueda. El listado recursivo se limita para mantener la app ágil."
    }
}

struct PromptTextEditor: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)

            if text.isEmpty {
                Text(prompt)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(ReplacerTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
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

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? ReplacerTheme.teal : ReplacerTheme.muted.opacity(0.6))

                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(hit.relativePath)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(ReplacerTheme.ink)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
