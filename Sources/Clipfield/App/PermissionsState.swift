import AppKit
import ApplicationServices

/// Tracks whether the app has Accessibility permission (needed to synthesize ⌘V
/// for auto-paste), polling so the UI can reflect a grant without a relaunch.
@MainActor
final class PermissionsState: ObservableObject {
    @Published private(set) var accessibilityTrusted = AXIsProcessTrusted()

    /// Called once when access transitions from not-granted to granted.
    var onBecameTrusted: (() -> Void)?

    private var timer: Timer?

    func startPolling() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        let trusted = AXIsProcessTrusted()
        guard trusted != accessibilityTrusted else { return }
        let wasTrusted = accessibilityTrusted
        accessibilityTrusted = trusted
        if trusted && !wasTrusted { onBecameTrusted?() }
    }

    /// Opens System Settings → Privacy & Security → Accessibility, and triggers
    /// the system prompt so the app is added to the list.
    func requestAccessibility() {
        _ = Paster.ensureAccessibilityPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
