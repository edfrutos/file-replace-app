import SwiftUI

@main
struct FileReplaceApp: App {
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
