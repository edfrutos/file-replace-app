import AppKit
import FileReplaceCore
import Foundation

enum ReplacerVersion {
    static let current: AppVersion = ReplacerBuildInfo.appVersion
}

@MainActor
enum UpdateCenter {
    private static let releasesURL = URL(
        string: "https://github.com/edfrutos/file-replace-app/releases"
    )!

    static func presentUpdateOptions() {
        let alert = NSAlert()
        alert.messageText = tr("Buscar actualizaciones", "Check for Updates")
        alert.informativeText = tr("Versión instalada: \(ReplacerVersion.current). Esta distribución es privada; GitHub solicitará una sesión con acceso al repositorio para consultar las releases disponibles.", "Installed version: \(ReplacerVersion.current). This distribution is private; GitHub will ask you to sign in with access to the repository to see the available releases.")
        alert.alertStyle = .informational
        alert.addButton(withTitle: tr("Abrir releases en GitHub", "Open Releases on GitHub"))
        alert.addButton(withTitle: tr("Cancelar", "Cancel"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if !NSWorkspace.shared.open(releasesURL) {
            let errorAlert = NSAlert()
            errorAlert.messageText = tr("No se pudo abrir GitHub", "Could not open GitHub")
            errorAlert.informativeText = tr("Abre manualmente:\n\(releasesURL.absoluteString)", "Open it manually:\n\(releasesURL.absoluteString)")
            errorAlert.alertStyle = .warning
            errorAlert.runModal()
        }
    }
}
