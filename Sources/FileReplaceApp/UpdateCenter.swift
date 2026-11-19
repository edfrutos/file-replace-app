import AppKit
import FileReplaceCore
import Foundation

enum ReplacerVersion {
    static let current: AppVersion = ReplacerBuildInfo.appVersion
}

@MainActor
enum UpdateCenter {
    /// Página pública de la app, con la última versión del DMG notarizado.
    private static let downloadPageURL = URL(string: "https://efjdev.com/replacer/")!

    static func presentUpdateOptions() {
        let alert = NSAlert()
        alert.messageText = tr("Buscar actualizaciones", "Check for Updates")
        alert.informativeText = tr("Versión instalada: \(ReplacerVersion.current). La página de Replacer en efjdev.com ofrece siempre la última versión, firmada y notarizada por Apple.", "Installed version: \(ReplacerVersion.current). The Replacer page on efjdev.com always offers the latest version, signed and notarized by Apple.")
        alert.alertStyle = .informational
        alert.addButton(withTitle: tr("Abrir la página de descarga", "Open Download Page"))
        alert.addButton(withTitle: tr("Cancelar", "Cancel"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if !NSWorkspace.shared.open(downloadPageURL) {
            let errorAlert = NSAlert()
            errorAlert.messageText = tr("No se pudo abrir la página", "Could not open the page")
            errorAlert.informativeText = tr("Abre manualmente:\n\(downloadPageURL.absoluteString)", "Open it manually:\n\(downloadPageURL.absoluteString)")
            errorAlert.alertStyle = .warning
            errorAlert.runModal()
        }
    }
}
