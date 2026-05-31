import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A click-to-record control that captures a key + modifier combination for the
/// global hotkey. Reports the Carbon key code and modifier mask plus a glyph
/// string (e.g. "⇧⌘V") for display.
struct HotkeyRecorder: NSViewRepresentable {
    @Binding var display: String
    var onRecord: (_ keyCode: UInt32, _ modifiers: UInt32, _ display: String) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.display = display
        view.onRecord = { keyCode, modifiers, glyphs in
            display = glyphs
            onRecord(keyCode, modifiers, glyphs)
        }
        return view
    }

    func updateNSView(_ view: RecorderView, context: Context) {
        if !view.isRecording {
            view.display = display
            view.needsDisplay = true
        }
    }
}

final class RecorderView: NSView {
    var display: String = ""
    var isRecording = false
    var onRecord: ((UInt32, UInt32, String) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 130, height: 26) }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.18)
                     : NSColor.controlBackgroundColor).setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.stroke()

        let text = isRecording ? "Press shortcut…" : (display.isEmpty ? "Click to record" : display)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }

        // Escape cancels recording.
        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            needsDisplay = true
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Require at least one non-shift modifier so the hotkey can't collide with
        // ordinary typing.
        guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else {
            NSSound.beep()
            return
        }

        let carbon = Self.carbonModifiers(flags)
        let glyphs = Self.glyphs(flags: flags, keyCode: event.keyCode,
                                 chars: event.charactersIgnoringModifiers)
        onRecord?(UInt32(event.keyCode), carbon, glyphs)

        isRecording = false
        window?.makeFirstResponder(nil)
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return super.resignFirstResponder()
    }

    // MARK: Conversion

    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        return mods
    }

    static func glyphs(flags: NSEvent.ModifierFlags, keyCode: UInt16, chars: String?) -> String {
        var out = ""
        if flags.contains(.control) { out += "⌃" }
        if flags.contains(.option) { out += "⌥" }
        if flags.contains(.shift) { out += "⇧" }
        if flags.contains(.command) { out += "⌘" }
        out += keyName(keyCode: keyCode, chars: chars)
        return out
    }

    private static func keyName(keyCode: UInt16, chars: String?) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return, kVK_ANSI_KeypadEnter: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default:
            if let chars, let first = chars.first {
                return String(first).uppercased()
            }
            return "?"
        }
    }
}
