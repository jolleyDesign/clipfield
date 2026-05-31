import AppKit
import Carbon.HIToolbox
import SwiftData

/// Pastes a stored clip into whichever app was focused before the overlay opened.
///
/// Flow: write the clip to the pasteboard → return focus to the previous app →
/// synthesize ⌘V. Synthesizing keystrokes requires Accessibility permission; if
/// it isn't granted we still set the clipboard (so the user can ⌘V manually) and
/// surface the system prompt.
@MainActor
enum Paster {
    static func paste(_ item: ClipItem,
                      into previousApp: NSRunningApplication?,
                      context: ModelContext,
                      plain: Bool = false) {
        if plain {
            ClipboardWriter.writePlain(item)
        } else {
            ClipboardWriter.write(item)
        }
        recordPaste(item, context: context)
        pasteFront(into: previousApp)
    }

    /// Pastes an arbitrary plain string (used by text transforms).
    static func pasteText(_ string: String, into previousApp: NSRunningApplication?) {
        ClipboardWriter.writeString(string)
        pasteFront(into: previousApp)
    }

    /// Restores focus to the previous app and synthesizes ⌘V.
    private static func pasteFront(into previousApp: NSRunningApplication?) {
        if let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp.activate()
        }

        guard ensureAccessibilityPermission() else {
            // Clipboard is set; user can paste manually once permission is granted.
            return
        }

        // Give the target app a beat to become frontmost before sending the key.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            sendPasteKeystroke()
        }
    }

    // MARK: Keystroke

    private static func sendPasteKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_V)

        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        up?.flags = .maskCommand

        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: Bookkeeping

    private static func recordPaste(_ item: ClipItem, context: ModelContext) {
        item.pasteCount += 1
        item.lastPastedAt = .now
        try? context.save()
    }

    // MARK: Accessibility

    /// Returns whether the process is trusted for Accessibility. Prompts the user
    /// (once) if it isn't yet.
    @discardableResult
    static func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
