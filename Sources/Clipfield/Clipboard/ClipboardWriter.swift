import AppKit

/// Writes a stored clip back onto the general pasteboard, restoring the richest
/// representation so styled text / images / files paste faithfully.
enum ClipboardWriter {
    static func write(_ item: ClipItem) {
        let pasteboard = NSPasteboard.general

        // Prefer the full captured flavors for a byte-perfect paste.
        if let raw = item.rawFlavors, PasteboardFlavors.restore(raw, to: pasteboard) {
            return
        }

        pasteboard.clearContents()

        switch item.kind {
        case .image:
            if let image = item.image {
                pasteboard.writeObjects([image])
                return
            }
        case .file:
            if let urlString = item.fileURLString, let url = URL(string: urlString) {
                pasteboard.writeObjects([url as NSURL])
                if let text = item.text { pasteboard.setString(text, forType: .string) }
                return
            }
        default:
            break
        }

        // Rich text: write RTF (+ HTML) alongside a plain-text fallback.
        if let rtf = item.rtfData {
            pasteboard.setData(rtf, forType: .rtf)
        }
        if let html = item.htmlString, let data = html.data(using: .utf8) {
            pasteboard.setData(data, forType: .html)
        }
        if let text = item.text {
            pasteboard.setString(text, forType: .string)
        }
    }

    /// Writes the item's plain-text representation only (strips formatting).
    /// Falls back to the rich write for items without text (e.g. images).
    static func writePlain(_ item: ClipItem) {
        guard let text = item.text, !text.isEmpty else {
            write(item)
            return
        }
        writeString(text)
    }

    /// Writes an arbitrary plain string to the pasteboard.
    static func writeString(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
