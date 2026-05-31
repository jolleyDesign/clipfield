import SwiftUI

@main
struct ClipfieldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu-bar item is a plain NSStatusItem managed in AppDelegate
        // (left-click opens the picker), so the only SwiftUI scene is Settings.
        Settings {
            SettingsView()
        }
        .modelContainer(DataController.shared.container)
    }
}
