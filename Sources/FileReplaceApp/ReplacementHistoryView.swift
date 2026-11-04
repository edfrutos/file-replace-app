import AppKit
import FileReplaceCore
import SwiftUI

// MARK: - Historial en el view model

extension FileReplaceViewModel {
    /// `~/Library/Application Support/Replacer/history.json`; con sandbox, dentro
    /// del contenedor de la app.
    nonisolated static var historyFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Replacer", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    /// Anota un reemplazo terminado. Guarda un marcador con permiso sobre la
    /// carpeta para poder restaurar aunque la app se haya cerrado entretanto.
    func recordBatch(directoryURL: URL, rules: [ReplacementRule], entries: [ReplacementBatch.Entry]) {
        let bookmark = try? directoryURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        history.insert(
            ReplacementBatch(
                directoryPath: directoryURL.path,
                directoryBookmark: bookmark,
                rules: rules,
                entries: entries
            ),
            at: 0
        )
        storeHistory()
    }

    /// Devuelve `entries` de `batch` a su copia de seguridad. El servicio se niega
    /// con los archivos modificados después del reemplazo; el resto se restaura.
    func restore(_ entries: [ReplacementBatch.Entry], from batch: ReplacementBatch) {
        let pending = entries.filter { $0.restoredAt == nil }
        guard !pending.isEmpty, !isWorking else { return }

        let alert = NSAlert()
        alert.messageText = tr("Restaurar archivos", "Restore Files")
        alert.informativeText = tr("Se devolverán \(pending.count) archivo(s) al contenido que tenían antes de este reemplazo. Si alguno se ha modificado después, se dejará como está.", "\(pending.count) file(s) will go back to the content they had before this replacement. Any file modified since then will be left as is.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: tr("Restaurar", "Restore"))
        alert.addButton(withTitle: tr("Cancelar", "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let folderURL = folderAccessURL(for: batch) else { return }

        let service = self.service
        isWorking = true
        statusMessage = tr("Restaurando \(pending.count) archivo(s)…", "Restoring \(pending.count) file(s)…")

        Task {
            let accessing = folderURL.startAccessingSecurityScopedResource()
            let outcomes: [(id: UUID, error: String?)] = await Task.detached(priority: .userInitiated) {
                pending.map { entry -> (id: UUID, error: String?) in
                    do {
                        try service.restore(entry)
                        return (entry.id, nil)
                    } catch {
                        return (entry.id, error.localizedDescription)
                    }
                }
            }.value
            if accessing {
                folderURL.stopAccessingSecurityScopedResource()
            }

            let now = Date()
            var lines: [String] = []
            var restored = 0
            for outcome in outcomes {
                guard let entry = pending.first(where: { $0.id == outcome.id }) else { continue }
                let name = batch.relativePath(of: entry)
                if let error = outcome.error {
                    lines.append("\(name): \(error)")
                } else {
                    restored += 1
                    lines.append(tr("\(name): restaurado desde \(entry.backupURL.lastPathComponent)", "\(name): restored from \(entry.backupURL.lastPathComponent)"))
                    markRestored(entry.id, in: batch.id, at: now)
                }
            }
            storeHistory()

            replacementLog = lines
            isWorking = false
            refreshResults(statusPrefix: tr("Restaurados \(restored) de \(pending.count) archivo(s).", "Restored \(restored) of \(pending.count) file(s)."))
        }
    }

    func clearHistory() {
        let alert = NSAlert()
        alert.messageText = tr("Vaciar historial", "Clear History")
        alert.informativeText = tr("Se olvidarán todos los reemplazos anteriores y ya no podrás restaurarlos desde aquí. Las copias .replacer-backup no se borran.", "All previous replacements will be forgotten and you will no longer be able to restore them from here. The .replacer-backup copies are not deleted.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: tr("Vaciar", "Clear"))
        alert.addButton(withTitle: tr("Cancelar", "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        history = []
        storeHistory()
    }

    private func markRestored(_ entryID: UUID, in batchID: UUID, at date: Date) {
        guard let batchIndex = history.firstIndex(where: { $0.id == batchID }),
              let entryIndex = history[batchIndex].entries.firstIndex(where: { $0.id == entryID }) else { return }
        history[batchIndex].entries[entryIndex].restoredAt = date
    }

    private func storeHistory() {
        history = Array(history.prefix(ReplacementHistoryStore.maxBatches))
        do {
            try historyStore.save(history)
        } catch {
            statusMessage = tr("No se pudo guardar el historial: \(error.localizedDescription)", "Could not save the history: \(error.localizedDescription)")
        }
    }

    /// Carpeta del lote con permiso de escritura. Con sandbox, si el marcador no
    /// sirve (carpeta movida, historial antiguo), solo el usuario puede volver a
    /// dar acceso eligiéndola en el panel.
    private func folderAccessURL(for batch: ReplacementBatch) -> URL? {
        if let bookmark = batch.directoryBookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if isStale,
                   let index = history.firstIndex(where: { $0.id == batch.id }),
                   let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                    history[index].directoryBookmark = fresh
                    storeHistory()
                }
                return url
            }
        }

        #if APPSTORE_BUILD
        NSApp.activate()

        let folderURL = URL(fileURLWithPath: batch.directoryPath)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = folderURL
        panel.prompt = tr("Dar acceso", "Grant Access")
        panel.message = tr("Para restaurar, Replacer necesita permiso para escribir en «\(folderURL.lastPathComponent)». Selecciona esa carpeta.", "To restore, Replacer needs permission to write to “\(folderURL.lastPathComponent)”. Select that folder.")

        guard panel.runModal() == .OK, let url = panel.url else {
            statusMessage = tr("Restauración cancelada: no se dio acceso a la carpeta.", "Restore cancelled: access to the folder was not granted.")
            return nil
        }
        guard batch.directoryPath.hasPrefix(url.standardizedFileURL.path) else {
            statusMessage = tr("Esa carpeta no contiene los archivos del reemplazo. Selecciona \(batch.directoryPath).", "That folder does not contain the replaced files. Select \(batch.directoryPath).")
            return nil
        }
        return url
        #else
        return URL(fileURLWithPath: batch.directoryPath)
        #endif
    }
}

extension ReplacementBatch {
    func relativePath(of entry: Entry) -> String {
        let base = directoryPath.hasSuffix("/") ? directoryPath : directoryPath + "/"
        return entry.filePath.hasPrefix(base) ? String(entry.filePath.dropFirst(base.count)) : entry.fileURL.lastPathComponent
    }

    /// «a» → «b» de los primeros pares, para reconocer el lote de un vistazo.
    var rulesSummary: String {
        let shown = rules.prefix(3).map { rule in
            tr("«\(rule.find)» → «\(rule.replace)»", "“\(rule.find)” → “\(rule.replace)”")
        }
        let more = rules.count > shown.count ? tr(" y \(rules.count - shown.count) más", " and \(rules.count - shown.count) more") : ""
        return shown.joined(separator: "  ·  ") + more
    }
}

// MARK: - Vista

/// Hoja con los reemplazos anteriores. Desde aquí se deshace un lote entero o
/// un archivo suelto, devolviéndolo a su `.replacer-backup`.
struct ReplacementHistoryView: View {
    @ObservedObject var viewModel: FileReplaceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var expandedBatchIDs = Set<UUID>()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 640, idealWidth: 760, minHeight: 460, idealHeight: 580)
        .background(ReplacerTheme.paper)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tr("Historial de reemplazos", "Replacement History"))
                .font(.headline.weight(.bold))
                .foregroundStyle(ReplacerTheme.ink)
            Text(tr("Deshaz un reemplazo devolviendo los archivos a su copia .replacer-backup. Un archivo solo se restaura si nadie lo ha modificado después del reemplazo.", "Undo a replacement by returning the files to their .replacer-backup copy. A file is only restored if nobody has modified it since the replacement."))
                .font(.callout)
                .foregroundStyle(ReplacerTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.history.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 34))
                    .foregroundStyle(ReplacerTheme.muted)
                Text(tr("Aún no has reemplazado nada.", "You have not replaced anything yet."))
                    .font(.callout)
                    .foregroundStyle(ReplacerTheme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.history) { batch in
                        BatchCard(
                            batch: batch,
                            isExpanded: expandedBatchIDs.contains(batch.id),
                            isWorking: viewModel.isWorking,
                            onToggleExpanded: { toggle(batch.id) },
                            onRestore: { entries in viewModel.restore(entries, from: batch) }
                        )
                    }
                }
                .padding(18)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button(role: .destructive) {
                viewModel.clearHistory()
            } label: {
                Label(tr("Vaciar historial", "Clear History"), systemImage: "trash")
            }
            .disabled(viewModel.history.isEmpty || viewModel.isWorking)

            Spacer()

            if viewModel.isWorking {
                ProgressView()
                    .controlSize(.small)
            }

            Button(tr("Cerrar", "Close")) {
                dismiss()
            }
            .buttonStyle(SoftButtonStyle())
            .keyboardShortcut(.cancelAction)
        }
        .padding(18)
    }

    private func toggle(_ id: UUID) {
        if expandedBatchIDs.contains(id) {
            expandedBatchIDs.remove(id)
        } else {
            expandedBatchIDs.insert(id)
        }
    }
}

private struct BatchCard: View {
    let batch: ReplacementBatch
    let isExpanded: Bool
    let isWorking: Bool
    let onToggleExpanded: () -> Void
    let onRestore: ([ReplacementBatch.Entry]) -> Void

    private var isFullyRestored: Bool {
        batch.pendingEntries.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(batch.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.callout.weight(.bold))
                        .foregroundStyle(ReplacerTheme.ink)
                    Label(URL(fileURLWithPath: batch.directoryPath).lastPathComponent, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(ReplacerTheme.muted)
                        .help(batch.directoryPath)
                }

                Spacer()

                Text(isFullyRestored
                     ? tr("Restaurado", "Restored")
                     : tr("\(batch.totalReplacements) reemplazo(s) en \(batch.entries.count) archivo(s)", "\(batch.totalReplacements) replacement(s) in \(batch.entries.count) file(s)"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isFullyRestored ? ReplacerTheme.teal : ReplacerTheme.blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background((isFullyRestored ? ReplacerTheme.teal : ReplacerTheme.blue).opacity(0.10))
                    .clipShape(Capsule())
            }

            Text(batch.rulesSummary)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(ReplacerTheme.ink)
                .lineLimit(2)

            HStack {
                Button(isExpanded ? tr("Ocultar archivos", "Hide files") : tr("Ver archivos", "Show files"), action: onToggleExpanded)
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.semibold))

                Spacer()

                Button {
                    onRestore(batch.pendingEntries)
                } label: {
                    Label(batch.entries.count == 1 ? tr("Restaurar", "Restore") : tr("Restaurar todo", "Restore all"), systemImage: "arrow.uturn.backward")
                }
                .disabled(isFullyRestored || isWorking)
                .help(tr("Devuelve los archivos de este reemplazo a su contenido anterior", "Returns the files of this replacement to their previous content"))
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(batch.entries) { entry in
                        EntryRow(
                            path: batch.relativePath(of: entry),
                            entry: entry,
                            isWorking: isWorking,
                            onRestore: { onRestore([entry]) }
                        )
                    }
                }
                .padding(10)
                .background(ReplacerTheme.tint)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(14)
        .background(ReplacerTheme.surface.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ReplacerTheme.border, lineWidth: 1)
        )
    }
}

private struct EntryRow: View {
    let path: String
    let entry: ReplacementBatch.Entry
    let isWorking: Bool
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundStyle(ReplacerTheme.muted)

            Text(path)
                .font(.caption)
                .foregroundStyle(ReplacerTheme.ink)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(entry.filePath)

            Text(tr("\(entry.replacements) reemplazo(s)", "\(entry.replacements) replacement(s)"))
                .font(.caption2)
                .foregroundStyle(ReplacerTheme.muted)

            Spacer()

            if let restoredAt = entry.restoredAt {
                Label(tr("Restaurado \(restoredAt.formatted(date: .omitted, time: .shortened))", "Restored \(restoredAt.formatted(date: .omitted, time: .shortened))"), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(ReplacerTheme.teal)
            } else {
                Button(tr("Restaurar", "Restore"), action: onRestore)
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.semibold))
                    .disabled(isWorking)
            }
        }
    }
}
