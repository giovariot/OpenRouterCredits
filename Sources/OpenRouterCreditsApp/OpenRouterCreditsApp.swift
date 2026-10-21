import AppKit
import SwiftUI

@main
struct OpenRouterCreditsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        // Una sola finestra: con WindowGroup ogni tocco sul widget (URL
        // openroutercredits://open) ne aprirebbe una nuova.
        Window("OpenRouter Credits", id: "main") {
            SettingsView(model: model)
                .onOpenURL { _ in
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}