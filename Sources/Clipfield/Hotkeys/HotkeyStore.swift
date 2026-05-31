import Foundation
import Carbon.HIToolbox

/// Persists the user's chosen global hotkey (Carbon key code + modifier mask)
/// along with a display string for the UI. Defaults to ⇧⌘V.
enum HotkeyStore {
    private static let keyCodeKey = "hotkeyKeyCode"
    private static let modifiersKey = "hotkeyModifiers"
    private static let displayKey = "hotkeyDisplay"

    static var keyCode: UInt32 {
        UInt32(UserDefaults.standard.object(forKey: keyCodeKey) as? Int ?? Int(kVK_ANSI_V))
    }

    static var modifiers: UInt32 {
        UInt32(UserDefaults.standard.object(forKey: modifiersKey) as? Int ?? Int(cmdKey | shiftKey))
    }

    static var display: String {
        UserDefaults.standard.string(forKey: displayKey) ?? "⇧⌘V"
    }

    static func set(keyCode: UInt32, modifiers: UInt32, display: String) {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: keyCodeKey)
        defaults.set(Int(modifiers), forKey: modifiersKey)
        defaults.set(display, forKey: displayKey)
    }
}
