import Foundation
import NaturalLanguage

/// Detects semantic categories for a clip's content (links, emails, phones,
/// addresses, dates, colors, code, numbers) entirely on-device, and refines the
/// item's primary `ClipKind` for single-value clips. No network, no ML services.
enum SmartTagger {
    struct Result {
        var kind: ClipKind
        var tags: [SmartTag]
    }

    static func analyze(_ capture: CapturedClip) -> Result {
        var tags = Set<SmartTag>()
        var kind = capture.kind

        switch capture.kind {
        case .image: tags.insert(.image)
        case .file: tags.insert(.file)
        default: break
        }

        guard let raw = capture.text else { return Result(kind: kind, tags: Array(tags)) }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return Result(kind: kind, tags: Array(tags)) }

        detectWithDataDetector(text, into: &tags)

        if matchesWhole(text, emailPattern) || containsMatch(text, emailPattern) {
            tags.insert(.email)
            tags.remove(.link) // mailto links shouldn't double as plain links
        }
        if matchesWhole(text, hexColorPattern) || matchesWhole(text, rgbColorPattern) {
            tags.insert(.color)
        }
        if matchesWhole(text, numberPattern) {
            tags.insert(.number)
        }
        if looksLikeCode(text) {
            tags.insert(.code)
        }

        kind = refinedKind(base: kind, text: text, tags: tags)
        return Result(kind: kind, tags: Array(tags))
    }

    // MARK: Data detector

    private static func detectWithDataDetector(_ text: String, into tags: inout Set<SmartTag>) {
        let types: NSTextCheckingResult.CheckingType = [.link, .phoneNumber, .address, .date]
        guard let detector = try? NSDataDetector(types: types.rawValue) else { return }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, options: [], range: range) {
            switch match.resultType {
            case .link:
                if match.url?.scheme == "mailto" { tags.insert(.email) } else { tags.insert(.link) }
            case .phoneNumber: tags.insert(.phone)
            case .address: tags.insert(.address)
            case .date: tags.insert(.date)
            default: break
            }
        }
    }

    // MARK: Kind refinement

    private static func refinedKind(base: ClipKind, text: String, tags: Set<SmartTag>) -> ClipKind {
        // Only refine plain/styled text whose entire content is one semantic value.
        guard base == .text || base == .richText else { return base }
        let singleToken = !text.contains(where: \.isWhitespace)

        if tags.contains(.email), matchesWhole(text, emailPattern) { return .email }
        if tags.contains(.color) { return .color }
        if tags.contains(.link), singleToken { return .link }
        if tags.contains(.phone), matchesWhole(text, phoneLikePattern) { return .phone }
        if tags.contains(.code) { return .code }
        return base
    }

    // MARK: Heuristics

    private static func looksLikeCode(_ text: String) -> Bool {
        let multiline = text.contains("\n")
        let symbols = ["{", "}", ";", "=>", "()", "</", "/>", "::", "->"]
        let keywords = ["func ", "def ", "class ", "import ", "const ", "let ", "var ",
                        "public ", "private ", "function ", "#include", "package ",
                        "return ", "struct ", "enum "]
        let hasSymbols = symbols.contains { text.contains($0) }
        let hasKeyword = keywords.contains { text.contains($0) }
        // Require some structure to avoid tagging ordinary prose.
        if multiline && (hasSymbols || hasKeyword) { return true }
        if hasKeyword && hasSymbols { return true }
        return false
    }

    // MARK: Regex helpers

    private static let emailPattern = "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}"
    private static let hexColorPattern = "#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})"
    private static let rgbColorPattern = "rgba?\\([^)]*\\)"
    private static let numberPattern = "[+-]?\\d[\\d,]*(\\.\\d+)?%?"
    private static let phoneLikePattern = "[+]?[\\d().\\-\\s]{7,}"

    private static func matchesWhole(_ text: String, _ pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: "^(?:\(pattern))$",
                                                   options: [.caseInsensitive]) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    private static func containsMatch(_ text: String, _ pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
