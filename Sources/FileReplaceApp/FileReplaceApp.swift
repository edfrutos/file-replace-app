import AppKit
import Combine
import FileReplaceCore
import SwiftUI

/// Al ejecutar como binario de SwiftPM (`swift run`) la app arranca sin bundle.
/// Fijar la política de activación y activarla mejora el foco de ventanas y
/// paneles; aun así, el panel nativo de carpetas puede requerir la app empaquetada.
@MainActor
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
            error.pointee = tr("Replacer no recibió ninguna carpeta.", "Replacer did not receive a folder.") as NSString
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
        case .light: return tr("Claro", "Light")
        case .dark: return tr("Oscuro", "Dark")
        case .system: return tr("Automático", "Automatic")
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

/// Idioma elegido en Ajustes. Se guarda como `AppleLanguages` en el dominio de
/// la app —lo mismo que hace Ajustes del Sistema con el idioma por app—, así que
/// también cambia los menús estándar de macOS. Solo se aplica al arrancar.
enum LanguagePreference: String, CaseIterable, Identifiable {
    case system, spanish = "es", english = "en"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return tr("Sistema", "System")
        case .spanish: return "Español"
        case .english: return "English"
        }
    }

    private static let defaultsKey = "AppleLanguages"

    /// Lo guardado en el dominio de la app, no el valor efectivo (que hereda
    /// el del sistema).
    static var stored: LanguagePreference {
        let domain = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
        guard let first = (domain?[defaultsKey] as? [String])?.first?.lowercased() else { return .system }
        if first.hasPrefix("es") { return .spanish }
        if first.hasPrefix("en") { return .english }
        return .system
    }

    func store() {
        if self == .system {
            UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
        } else {
            UserDefaults.standard.set([rawValue], forKey: Self.defaultsKey)
        }
    }

    /// Idioma que tendrá la app en el próximo arranque.
    var resolved: AppLanguage {
        switch self {
        case .spanish: return .spanish
        case .english: return .english
        case .system:
            let global = CFPreferencesCopyValue(
                "AppleLanguages" as CFString,
                kCFPreferencesAnyApplication,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            ) as? [String]
            return AppLanguage.resolve(global ?? Locale.preferredLanguages)
        }
    }

    /// Abre una instancia nueva de Replacer y cierra esta.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            guard error == nil else { return }
            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }
}

@main
struct FileReplaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(appearanceModeDefaultsKey) private var appearanceModeRaw = AppearanceMode.system.rawValue
    /// Vive aquí y no en la ventana para que los comandos del menú lleguen a él.
    @StateObject private var viewModel = FileReplaceViewModel()

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 860, minHeight: 620)
                .preferredColorScheme(appearanceMode.colorScheme)
                .onChange(of: appearanceModeRaw, initial: true) {
                    NSApp.appearance = appearanceMode.nsAppearance
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(tr("Empezar de nuevo", "Start Over")) {
                    viewModel.startOver()
                }
                .keyboardShortcut("n")
                .disabled(viewModel.isWorking)
            }
            #if !APPSTORE_BUILD
            CommandGroup(after: .appInfo) {
                Button(tr("Buscar actualizaciones…", "Check for Updates…")) {
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
    @State private var language = LanguagePreference.stored

    var body: some View {
        Form {
            Picker(tr("Apariencia", "Appearance"), selection: $appearanceModeRaw) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            // Sin esto el control segmentado ocupa todo el ancho y el Form
            // recorta la etiqueta «Apariencia» a su primera letra.
            .fixedSize()

            Picker(tr("Idioma", "Language"), selection: $language) {
                ForEach(LanguagePreference.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .onChange(of: language) {
                language.store()
            }

            if language.resolved != AppLanguage.current {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("El idioma cambiará al volver a abrir Replacer.", "The language will change the next time Replacer opens."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button(tr("Reiniciar ahora", "Restart Now")) {
                        LanguagePreference.relaunch()
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 380)
    }
}
