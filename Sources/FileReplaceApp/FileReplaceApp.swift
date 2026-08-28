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

@main
struct FileReplaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 860, minHeight: 620)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .appInfo) {
                Button("Buscar actualizaciones…") {
                    UpdateCenter.presentUpdateOptions()
                }
            }
        }
    }
}
