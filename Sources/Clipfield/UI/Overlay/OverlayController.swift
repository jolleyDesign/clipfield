import AppKit
import SwiftUI

/// Drives the overlay's open/close animation. The view observes `visible` and
/// scales/fades accordingly; the controller flips it and orders the window in/out.
@MainActor
final class OverlayPresentation: ObservableObject {
    @Published var visible = false
}

/// What the overlay asks the controller to do when an item is chosen.
enum OverlayPasteRequest {
    case item(ClipItem, plain: Bool)  // write (rich or plain) + paste
    case text(String)                 // write an arbitrary string + paste (transforms)
    case copyItem(ClipItem)           // copy to clipboard only, no paste
}

/// Owns the Spotlight-style overlay panel: shows/hides it, captures the app that
/// was focused before it appeared, and handles selection.
@MainActor
final class OverlayController: NSObject, NSWindowDelegate {
    private var panel: OverlayPanel?
    private(set) var previousApp: NSRunningApplication?
    private let presentation = OverlayPresentation()

    /// Duration of the close animation before the window is ordered out.
    private let closeDuration = 0.16

    /// The window content size: the user's persisted (dragged) size if any,
    /// otherwise the preset from appearance settings.
    private var panelSize: NSSize {
        let defaults = UserDefaults.standard
        let w = defaults.double(forKey: AppearanceKeys.contentWidth)
        let h = defaults.double(forKey: AppearanceKeys.contentHeight)
        if w > 0, h > 0 {
            // Clamp to sane bounds so a stale/bad persisted value can't make the
            // window enormous or unusably small.
            return NSSize(width: min(max(w, 560), 1600), height: min(max(h, 380), 1100))
        }
        return OverlaySize.current.card
    }

    /// App activation is async; ignore the transient resign-key that can fire while
    /// the panel is still coming up (e.g. when summoned from the menu-bar popover).
    private var suppressResignUntil: Date = .distantPast

    func toggle() {
        if panel?.isVisible == true { dismiss() } else { show() }
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication

        let panel = panel ?? makePanel()
        self.panel = panel
        presentation.visible = false      // start collapsed, then bounce in
        installContent(on: panel)         // fresh SwiftUI each open → reset search
        position(panel)
        suppressResignUntil = Date().addingTimeInterval(0.4)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        // Activating an accessory app is async and occasionally drops the first
        // attempt; re-assert key status on the next runloop tick so the search
        // field reliably gains focus without needing a mouse hover.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKey()
            // Fast bounce-in.
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                self.presentation.visible = true
            }
        }
    }

    /// Animates the card out, then orders the window out and runs `completion`.
    private func animateOut(completion: (() -> Void)? = nil) {
        guard let panel, panel.isVisible else { completion?(); return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
            presentation.visible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + closeDuration) {
            panel.orderOut(nil)
            completion?()
        }
    }

    func hide() {
        animateOut()
    }

    // MARK: Building

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel(contentRect: NSRect(origin: .zero, size: panelSize))
        panel.delegate = self
        return panel
    }

    private func installContent(on panel: OverlayPanel) {
        let root = OverlayView(
            presentation: presentation,
            onPaste: { [weak self] request in self?.commit(request) },
            onClose: { [weak self] in self?.dismiss() }
        )
        .modelContainer(DataController.shared.container)

        let host = NSHostingView(rootView: root)
        // Don't let the hosting view drive the window size from the SwiftUI
        // content's fitting size — the window controls its own frame, and the
        // content fills it. Otherwise the flexible content blows the window up.
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: panelSize)
        panel.contentView = host
    }

    // MARK: Selection

    /// Handles a chosen item. Set by `AppDelegate` to perform the actual paste;
    /// the default just restores the clipboard and returns focus.
    var pasteHandler: ((OverlayPasteRequest, NSRunningApplication?) -> Void)?

    private func commit(_ request: OverlayPasteRequest) {
        let app = previousApp
        animateOut { [weak self] in
            guard let self else { return }
            if let pasteHandler = self.pasteHandler {
                pasteHandler(request, app)
            } else if case .item(let item, _) = request {
                ClipboardWriter.write(item)
                app?.activate()
            }
        }
    }

    private func dismiss() {
        animateOut { [weak self] in
            self?.previousApp?.activate()
        }
    }

    // MARK: Geometry

    private func position(_ panel: NSPanel) {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let x = visible.midX - panelSize.width / 2
        // Sit a little above dead-center — reads better than perfectly centered.
        let y = visible.midY - panelSize.height / 2 + visible.height * 0.08
        panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
    }

    // MARK: NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // Spotlight-style: dismiss as soon as focus leaves the panel (clicking
        // another window/app, switching spaces, etc.). The brief post-show
        // suppression window covers async activation right after opening.
        guard Date() >= suppressResignUntil else { return }
        hide()
    }

    func windowDidResize(_ notification: Notification) {
        guard let panel else { return }
        let size = panel.frame.size
        let defaults = UserDefaults.standard
        defaults.set(Double(size.width), forKey: AppearanceKeys.contentWidth)
        defaults.set(Double(size.height), forKey: AppearanceKeys.contentHeight)
    }
}
