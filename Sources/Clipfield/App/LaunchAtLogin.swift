import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` for launch-at-login. Requires the
/// app to run from a real bundle (e.g. /Applications); registration may fail
/// silently during raw `swift run` development.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LaunchAtLogin toggle failed: \(error.localizedDescription)")
        }
    }
}
