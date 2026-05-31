import SwiftUI
import AppKit

/// A search field that forwards navigation keys (↑ ↓ ↩ ⎋) to callbacks instead
/// of letting them move the text cursor. This is the reliable way to drive a
/// keyboard-navigable results list while a text field holds focus.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    /// When true (no inline prompt is up), the field reclaims focus if it lost it.
    var isActive: Bool = true
    var onMoveUp: () -> Void = {}
    var onMoveDown: () -> Void = {}
    var onSubmit: () -> Void = {}
    var onSubmitPlain: () -> Void = {}
    var onToggleStack: () -> Void = {}
    var onPasteStack: () -> Void = {}
    var onDeleteWhenEmpty: () -> Void = {}
    var onCancel: () -> Void = {}

    func makeNSView(context: Context) -> AutoFocusSearchField {
        let field = AutoFocusSearchField()
        field.placeholderString = "Search clipboard…"
        field.delegate = context.coordinator
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.font = .systemFont(ofSize: 15)
        field.sendsWholeSearchString = false
        field.sendsSearchStringImmediately = true
        (field.cell as? NSSearchFieldCell)?.searchButtonCell?.isTransparent = false
        return field
    }

    func updateNSView(_ field: AutoFocusSearchField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        context.coordinator.parent = self

        // Reclaim focus when active (e.g. after an inline prompt that stole it
        // closes), so keyboard navigation keeps working without a click.
        if isActive {
            DispatchQueue.main.async {
                guard let window = field.window, window.isKeyWindow else { return }
                if window.firstResponder !== field.currentEditor() {
                    window.makeFirstResponder(field)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField

        init(_ parent: SearchField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)):
                parent.onMoveUp(); return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onMoveDown(); return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit(); return true
            case #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)):
                parent.onSubmitPlain(); return true // ⌥↩ — paste as plain text
            case #selector(NSResponder.insertTab(_:)):
                parent.onToggleStack(); return true // ⇥ — add/remove from paste stack
            case #selector(NSResponder.insertLineBreak(_:)):
                parent.onPasteStack(); return true  // ⇧↩ — paste the whole stack
            case #selector(NSResponder.deleteToBeginningOfLine(_:)):
                // ⌘⌫: clear the field if there's text; otherwise delete the item.
                if textView.string.isEmpty {
                    parent.onDeleteWhenEmpty()
                    return true
                }
                return false // let the field editor clear to the start of the line
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel(); return true
            default:
                return false
            }
        }
    }
}

/// Grabs first-responder as soon as its window becomes key. Activating an
/// accessory app is asynchronous, so the panel often isn't key yet when the
/// field first appears — focusing only on appear would leave keyboard input
/// dead until the user clicked/hovered. Listening for `didBecomeKey` fixes that.
final class AutoFocusSearchField: NSSearchField {
    private var keyObserver: NSObjectProtocol?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let keyObserver {
            NotificationCenter.default.removeObserver(keyObserver)
            self.keyObserver = nil
        }
        guard let window else { return }

        if window.isKeyWindow {
            focusSelf()
        } else {
            // Make ourselves the desired first responder now; AppKit activates the
            // field editor once the window becomes key.
            window.makeFirstResponder(self)
        }

        keyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.focusSelf()
        }
    }

    private func focusSelf() {
        window?.makeFirstResponder(self)
    }

    deinit {
        if let keyObserver {
            NotificationCenter.default.removeObserver(keyObserver)
        }
    }
}
