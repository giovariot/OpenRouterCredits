import AppKit
import SwiftUI

@main
struct OpenRouterCreditsApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("OpenRouter Credits") {
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