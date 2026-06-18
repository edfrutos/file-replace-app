import AppKit
import FileReplaceCore
import Foundation

enum ReplacerVersion {
    static let current: AppVersion = {
        guard
            let url = Bundle.module.url(forResource: "Version", withExtension: "txt"),
            let value = try? String(contentsOf: url, encoding: .utf8),
            let version = AppVersion(value)
        else {
            preconditionFailure("No se pudo leer Resources/Version.txt")
        }
        return version
    }()
}

@MainActor
enum UpdateCenter {
    private static let releasesURL = URL(
        string: "https://github.com/edfrutos/file-replace-app/releases"
    )!

    static func presentUpdateOptions() {
        let alert = NSAlert()
        alert.messageText = "Buscar actualizaciones"
        alert.informativeText = "Versión instalada: \(ReplacerVersion.current). Esta distribución es privada; GitHub solicitará una sesión con acceso al repositorio para consultar las releases disponibles."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Abrir releases en GitHub")
        alert.addButton(withTitle: "Cancelar")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if !NSWorkspace.shared.open(releasesURL) {
            let errorAlert = NSAlert()
            errorAlert.messageText = "No se pudo abrir GitHub"
            errorAlert.informativeText = "Abre manualmente:\n\(releasesURL.absoluteString)"
            errorAlert.alertStyle = .warning
            errorAlert.runModal()
        }
    }
}
