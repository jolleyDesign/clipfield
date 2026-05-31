import Foundation
import SwiftData
import AppKit

@Model
final class ClipItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var lastPastedAt: Date?
    var pasteCount: Int
    var pinned: Bool

    /// Primary content type (see `ClipKind`).
    var kindRaw: String
    /// Auto-detected semantic categories (see `SmartTag`), stored as raw values.
    var tagsRaw: [String]

    /// Whether this row's payload blobs hold AES-GCM ciphertext (true) or plaintext
    /// (false). Tracked per-item so a toggle can re-encrypt history incrementally
    /// while old and new rows coexist. See `CryptoVault`.
    var encrypted: Bool

    // MARK: Encrypted payload storage
    //
    // These persisted `*Cipher` blobs back the public payload accessors below.
    // When `encrypted` is false they hold plaintext (UTF-8 for strings, raw bytes
    // for data); when true they hold sealed AES-GCM boxes. Call sites only ever
    // touch the computed accessors, so encryption is transparent to the rest of
    // the app. Large blobs use external storage to keep the SQLite store small.

    private var textCipher: Data?
    private var rtfDataCipher: Data?
    private var htmlStringCipher: Data?
    @Attribute(.externalStorage) private var imageCipher: Data?
    @Attribute(.externalStorage) private var thumbnailCipher: Data?
    @Attribute(.externalStorage) private var rawFlavorsCipher: Data?
    private var fileURLStringCipher: Data?

    /// App the content was copied from, for display.
    var sourceAppName: String?
    var sourceAppBundleID: String?

    /// Stable hash of the primary content, used for de-duplication. Kept in clear
    /// (it is a non-reversible hash) so the dedup `#Predicate` can query it.
    var contentHash: String

    var folder: Folder?

    init(
        kind: ClipKind,
        contentHash: String,
        createdAt: Date = .now,
        text: String? = nil,
        rtfData: Data? = nil,
        htmlString: String? = nil,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        rawFlavors: Data? = nil,
        fileURLString: String? = nil,
        tags: [SmartTag] = [],
        sourceAppName: String? = nil,
        sourceAppBundleID: String? = nil
    ) {
        // Initialize every *stored* property first (definite initialization) so the
        // computed payload setters below — which read `encrypted` and write `self` —
        // are legal to call.
        self.id = UUID()
        self.createdAt = createdAt
        self.lastPastedAt = nil
        self.pasteCount = 0
        self.pinned = false
        self.kindRaw = kind.rawValue
        self.tagsRaw = tags.map(\.rawValue)
        self.encrypted = CryptoVault.shared.shouldEncryptNewItems
        self.textCipher = nil
        self.rtfDataCipher = nil
        self.htmlStringCipher = nil
        self.imageCipher = nil
        self.thumbnailCipher = nil
        self.rawFlavorsCipher = nil
        self.fileURLStringCipher = nil
        self.contentHash = contentHash
        self.sourceAppName = sourceAppName
        self.sourceAppBundleID = sourceAppBundleID
        self.folder = nil

        // Now `self` is fully initialized — encode the payloads via the accessors.
        self.text = text
        self.rtfData = rtfData
        self.htmlString = htmlString
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.rawFlavors = rawFlavors
        self.fileURLString = fileURLString
    }

    // MARK: Payload accessors (transparent encrypt/decrypt)

    /// Plain-text representation, used for search and as a fallback for display.
    var text: String? {
        get { CryptoVault.shared.decodeString(textCipher, encrypted: encrypted) }
        set { textCipher = CryptoVault.shared.encodeString(newValue, encrypted: encrypted) }
    }

    /// Rich text payload (RTF), preserved so styled text pastes with formatting.
    var rtfData: Data? {
        get { CryptoVault.shared.decodeData(rtfDataCipher, encrypted: encrypted) }
        set { rtfDataCipher = CryptoVault.shared.encodeData(newValue, encrypted: encrypted) }
    }

    /// HTML payload when available (e.g. copied from a browser).
    var htmlString: String? {
        get { CryptoVault.shared.decodeString(htmlStringCipher, encrypted: encrypted) }
        set { htmlStringCipher = CryptoVault.shared.encodeString(newValue, encrypted: encrypted) }
    }

    /// Image payload (PNG).
    var imageData: Data? {
        get { CryptoVault.shared.decodeData(imageCipher, encrypted: encrypted) }
        set { imageCipher = CryptoVault.shared.encodeData(newValue, encrypted: encrypted) }
    }

    /// Small PNG thumbnail for fast list rendering (images only).
    var thumbnailData: Data? {
        get { CryptoVault.shared.decodeData(thumbnailCipher, encrypted: encrypted) }
        set {
            thumbnailCipher = CryptoVault.shared.encodeData(newValue, encrypted: encrypted)
            CryptoVault.shared.invalidateThumbnail(id: id)
        }
    }

    /// All pasteboard flavors, serialized, for byte-perfect paste. Falls back to
    /// the curated representation when absent (e.g. oversized content).
    var rawFlavors: Data? {
        get { CryptoVault.shared.decodeData(rawFlavorsCipher, encrypted: encrypted) }
        set { rawFlavorsCipher = CryptoVault.shared.encodeData(newValue, encrypted: encrypted) }
    }

    /// File URL string when a file/folder reference was copied.
    var fileURLString: String? {
        get { CryptoVault.shared.decodeString(fileURLStringCipher, encrypted: encrypted) }
        set { fileURLStringCipher = CryptoVault.shared.encodeString(newValue, encrypted: encrypted) }
    }

    // MARK: Encryption mode

    /// Re-encodes every payload to match `enabled`, preserving content. Idempotent,
    /// so an interrupted re-encryption pass is safe to re-run. `contentHash` (clear
    /// metadata) is intentionally left untouched.
    func applyEncryption(_ enabled: Bool) {
        guard enabled != encrypted else { return }
        // Capture all plaintext in the *current* mode before flipping the flag, so
        // later fields aren't decoded with the wrong mode mid-pass.
        let t = text, r = rtfData, h = htmlString, img = imageData,
            th = thumbnailData, raw = rawFlavors, f = fileURLString
        encrypted = enabled
        text = t
        rtfData = r
        htmlString = h
        imageData = img
        thumbnailData = th
        rawFlavors = raw
        fileURLString = f
    }

    // MARK: Derived

    var kind: ClipKind {
        get { ClipKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var tags: [SmartTag] {
        get { tagsRaw.compactMap(SmartTag.init(rawValue:)) }
        set { tagsRaw = newValue.map(\.rawValue) }
    }

    var image: NSImage? {
        guard let imageData else { return nil }
        return NSImage(data: imageData)
    }

    /// Small thumbnail for list rows; falls back to the full image.
    var thumbnail: NSImage? {
        if let cached = CryptoVault.shared.cachedThumbnail(id: id, cipher: thumbnailCipher, encrypted: encrypted) {
            return cached
        }
        return image
    }

    /// A short single-line string for list rows.
    var previewText: String {
        if let text, !text.isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.replacingOccurrences(of: "\n", with: " ")
        }
        switch kind {
        case .image:
            if let image { return "Image · \(Int(image.size.width))×\(Int(image.size.height))" }
            return "Image"
        case .file:
            if let fileURLString, let url = URL(string: fileURLString) {
                return url.lastPathComponent
            }
            return "File"
        default:
            return kind.label
        }
    }
}
