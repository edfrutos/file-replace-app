import AppKit
import SwiftUI

/// Al ejecutar como binario de SwiftPM (`swift run`) la app arranca sin bundle.
/// Fijar la política de activación y activarla mejora el foco de ventanas y
/// paneles; aun así, el panel nativo de carpetas puede requerir la app empaquetada.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
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
        }
        .padding(24)
        .frame(width: 340)
    }
}
