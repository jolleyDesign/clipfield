import Foundation

/// Filters clip history by free text and smart-tag tokens.
///
/// A query word that names a smart tag (e.g. "email", "link", "image") becomes a
/// tag requirement; remaining words are matched against the item's text, preview,
/// and source app. An explicit `activeTag` filter (from a chip) is ANDed on top.
enum SearchEngine {
    static func filter(_ items: [ClipItem], query: String, activeTag: SmartTag?) -> [ClipItem] {
        let tokens = query
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        var requiredTags: Set<SmartTag> = []
        if let activeTag { requiredTags.insert(activeTag) }
        var textTokens: [String] = []

        for token in tokens {
            if let tag = tagNamed(token) {
                requiredTags.insert(tag)
            } else {
                textTokens.append(token)
            }
        }

        return items.filter { item in
            matchesTags(item, requiredTags) && matchesText(item, textTokens)
        }
    }

    private static func tagNamed(_ token: String) -> SmartTag? {
        SmartTag.allCases.first { $0.rawValue == token || $0.label.lowercased() == token }
    }

    private static func matchesTags(_ item: ClipItem, _ required: Set<SmartTag>) -> Bool {
        guard !required.isEmpty else { return true }
        let tags = Set(item.tags)
        return required.isSubset(of: tags)
    }

    private static func matchesText(_ item: ClipItem, _ tokens: [String]) -> Bool {
        guard !tokens.isEmpty else { return true }
        let haystack = [item.previewText, item.text ?? "", item.sourceAppName ?? ""]
            .joined(separator: " ")
            .lowercased()
        return tokens.allSatisfy { haystack.contains($0) }
    }
}
