import AppKit

/// Captures and restores the *complete* set of pasteboard representations
/// ("flavors") so a paste is byte-for-byte faithful — preserving app-specific
/// types that the curated text/image/file extraction would drop.
enum PasteboardFlavors {
    /// Don't store raw flavors above this total size; fall back to the curated
    /// representation so the history store stays bounded.
    static let maxRawBytes = 16 * 1024 * 1024 // 16 MB

    /// A pasteboard's items, each as a map of type identifier → raw data.
    struct Bundle: Codable {
        var items: [[String: Data]]
    }

    /// Serializes every flavor of every pasteboard item, or `nil` if there's
    /// nothing to store or the total exceeds `maxRawBytes`.
    static func capture(_ pasteboard: NSPasteboard) -> Data? {
        guard let items = pasteboard.pasteboardItems else { return nil }
        var bundle: [[String: Data]] = []
        var total = 0

        for item in items {
            var map: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    map[type.rawValue] = data
                    total += data.count
                }
            }
            if !map.isEmpty { bundle.append(map) }
        }

        guard !bundle.isEmpty, total <= maxRawBytes else { return nil }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try? encoder.encode(Bundle(items: bundle))
    }

    /// Restores serialized flavors to the pasteboard. Returns `false` if the data
    /// couldn't be decoded (caller should fall back to a curated write).
    @discardableResult
    static func restore(_ data: Data, to pasteboard: NSPasteboard) -> Bool {
        guard let bundle = try? PropertyListDecoder().decode(Bundle.self, from: data),
              !bundle.items.isEmpty else { return false }

        pasteboard.clearContents()
        let pbItems = bundle.items.map { map -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in map {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            return item
        }
        return pasteboard.writeObjects(pbItems)
    }
}
