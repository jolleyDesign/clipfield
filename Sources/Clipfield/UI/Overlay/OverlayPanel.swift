import AppKit

/// A borderless, resizable floating panel for the Spotlight-style picker.
/// Borderless windows can't become key by default, so we override the two
/// `canBecome…` properties to allow text input in the search field.
final class OverlayPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true // follows the rounded SwiftUI content's alpha shape
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        // The content view (filling the window) is clipped to a rounded rect; the
        // window stays clear so its shadow tracks that shape.
        contentMinSize = NSSize(width: 560, height: 380)
        contentMaxSize = NSSize(width: 1600, height: 1100)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
