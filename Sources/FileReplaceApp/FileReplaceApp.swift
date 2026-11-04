import AppKit
import Combine
import SwiftUI

/// Al ejecutar como binario de SwiftPM (`swift run`) la app arranca sin bundle.
/// Fijar la política de activación y activarla mejora el foco de ventanas y
/// paneles; aun así, el panel nativo de carpetas puede requerir la app empaquetada.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Replacer trabaja con una sola ventana (no hay «Nueva ventana»), así
        // que se desactivan las pestañas de macOS y su barra. Debe fijarse
        // antes de que se cree la primera ventana.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.servicesProvider = self
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Carpeta abierta desde Finder («Abrir con») o soltada en el icono del Dock.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        FolderOpenRequests.shared.pendingURL = url
        NSApp.activate()
    }

    /// Servicio «Buscar y reemplazar con Replacer» (clic derecho en una carpeta
    /// en Finder ▸ Servicios / Acciones rápidas). Finder no ofrece «Abrir con»
    /// para carpetas; el nombre del mensaje está en `NSServices` del Info.plist.
    @objc func openFolderService(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]
        guard let url = urls?.first else {
            error.pointee = "Replacer no recibió ninguna carpeta." as NSString
            return
        }
        FolderOpenRequests.shared.pendingURL = url
        NSApp.activate()
    }
}

/// Buzón entre el delegado de la app y la ventana: si la carpeta llega al
/// arrancar, antes de que exista la ventana, espera aquí hasta que la recoja.
@MainActor
final class FolderOpenRequests: ObservableObject {
    static let shared = FolderOpenRequests()

    @Published var pendingURL: URL?
}

/// Preferencia de apariencia persistida en `UserDefaults` bajo la misma clave
/// que lee `PreferencesView`, así que un cambio en Preferencias se refleja de
/// inmediato en la ventana principal sin reiniciar la app.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case light, dark, system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "Claro"
        case .dark: return "Oscuro"
        case .system: return "Automático"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    /// `preferredColorScheme` solo afecta a las vistas SwiftUI; los paneles y
    /// alertas de AppKit (NSOpenPanel, NSAlert) y la barra de título siguen la
    /// apariencia de `NSApp`, así que también se fija ahí. `nil` = la del sistema.
    var nsAppearance: NSAppearance? {
        switch self {
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        case .system: return nil
        }
    }
}

private let appearanceModeDefaultsKey = "replacerAppearanceMode"

@main
struct FileReplaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(appearanceModeDefaultsKey) private var appearanceModeRaw = AppearanceMode.system.rawValue

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 860, minHeight: 620)
                .preferredColorScheme(appearanceMode.colorScheme)
                .onChange(of: appearanceModeRaw, initial: true) {
                    NSApp.appearance = appearanceMode.nsAppearance
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            #if !APPSTORE_BUILD
            CommandGroup(after: .appInfo) {
                Button("Buscar actualizaciones…") {
                    UpdateCenter.presentUpdateOptions()
                }
            }
            #endif
        }

        Settings {
            PreferencesView()
                .preferredColorScheme(appearanceMode.colorScheme)
        }
    }
}

struct PreferencesView: View {
    @AppStorage(appearanceModeDefaultsKey) private var appearanceModeRaw = AppearanceMode.system.rawValue

    var body: some View {
        Form {
            Picker("Apariencia", selection: $appearanceModeRaw) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            // Sin esto el control segmentado ocupa todo el ancho y el Form
            // recorta la etiqueta «Apariencia» a su primera letra.
            .fixedSize()
        }
        .padding(24)
        .frame(minWidth: 340)
    }
}
