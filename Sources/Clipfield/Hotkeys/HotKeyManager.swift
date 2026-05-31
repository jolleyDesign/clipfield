import AppKit
import Carbon.HIToolbox

/// Registers a system-wide hotkey via Carbon `RegisterEventHotKey`. This works
/// without Accessibility permission (unlike an `NSEvent` global monitor) and is
/// what higher-level libraries wrap under the hood.
final class HotKeyManager {
    static let shared = HotKeyManager()

    /// Invoked on the main thread when the hotkey fires.
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    /// Registers the hotkey. Defaults to ⌘⇧V.
    func register(keyCode: UInt32 = UInt32(kVK_ANSI_V),
                  modifiers: UInt32 = UInt32(cmdKey | shiftKey)) {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ -> OSStatus in
                HotKeyManager.shared.onTrigger?()
                return noErr
            },
            1,
            &eventType,
            nil,
            &handlerRef
        )

        // 'CLIP'
        let hotKeyID = EventHotKeyID(signature: 0x434C4950, id: 1)
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }
}
