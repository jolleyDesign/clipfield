import Foundation
import SwiftData

/// A saved, reusable piece of text (unlike a captured clip). Content may contain
/// `{{placeholder}}` fields that are filled in when the snippet is pasted.
@Model
final class Snippet {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var lastUsedAt: Date?
    var usageCount: Int
    var sortIndex: Int

    /// Whether `contentCipher` holds ciphertext (see `CryptoVault` / `ClipItem`).
    var encrypted: Bool
    /// Backs the `content` accessor; plaintext or AES-GCM sealed per `encrypted`.
    private var contentCipher: Data?

    init(title: String, content: String, sortIndex: Int = 0, createdAt: Date = .now) {
        // Stored properties first, then the computed `content` setter.
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.lastUsedAt = nil
        self.usageCount = 0
        self.sortIndex = sortIndex
        self.encrypted = CryptoVault.shared.shouldEncryptNewItems
        self.contentCipher = nil

        self.content = content
    }

    /// The snippet body. Stored encrypted at rest when encryption is enabled.
    var content: String {
        get { CryptoVault.shared.decodeString(contentCipher, encrypted: encrypted) ?? "" }
        set { contentCipher = CryptoVault.shared.encodeString(newValue, encrypted: encrypted) }
    }

    /// Re-encodes `content` to match `enabled`. Idempotent. See `ClipItem.applyEncryption`.
    func applyEncryption(_ enabled: Bool) {
        guard enabled != encrypted else { return }
        let c = content
        encrypted = enabled
        content = c
    }

    /// Unique placeholder names in first-appearance order, e.g. `["name", "date"]`.
    var placeholders: [String] { Snippet.placeholders(in: content) }

    var preview: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }

    static func placeholders(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\{\{\s*([^}]+?)\s*\}\}"#) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        var seen: [String] = []
        for match in regex.matches(in: text, range: range) {
            guard let r = Range(match.range(at: 1), in: text) else { continue }
            let name = String(text[r])
            if !seen.contains(name) { seen.append(name) }
        }
        return seen
    }

    /// Substitutes `{{name}}` occurrences with the provided values.
    func filled(with values: [String: String]) -> String {
        var result = content
        for name in placeholders {
            let value = values[name] ?? ""
            let pattern = #"\{\{\s*"# + NSRegularExpression.escapedPattern(for: name) + #"\s*\}\}"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            let template = NSRegularExpression.escapedTemplate(for: value)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: template)
        }
        return result
    }
}
