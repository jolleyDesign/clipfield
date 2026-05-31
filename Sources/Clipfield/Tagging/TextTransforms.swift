import Foundation

/// Text transformations offered in the per-item actions menu. Each returns the
/// transformed string, or `nil` if it doesn't apply (e.g. invalid Base64/JSON).
enum TextTransform: String, CaseIterable, Identifiable {
    case uppercase
    case lowercase
    case titleCase
    case trim
    case base64Encode
    case base64Decode
    case jsonPrettify

    var id: String { rawValue }

    var label: String {
        switch self {
        case .uppercase: return "UPPERCASE"
        case .lowercase: return "lowercase"
        case .titleCase: return "Title Case"
        case .trim: return "Trim Whitespace"
        case .base64Encode: return "Base64 Encode"
        case .base64Decode: return "Base64 Decode"
        case .jsonPrettify: return "Prettify JSON"
        }
    }

    func apply(to text: String) -> String? {
        switch self {
        case .uppercase:
            return text.uppercased()
        case .lowercase:
            return text.lowercased()
        case .titleCase:
            return text.capitalized
        case .trim:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .base64Encode:
            return Data(text.utf8).base64EncodedString()
        case .base64Decode:
            guard let data = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let decoded = String(data: data, encoding: .utf8) else { return nil }
            return decoded
        case .jsonPrettify:
            guard let data = text.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let pretty = try? JSONSerialization.data(
                    withJSONObject: object,
                    options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                  ) else { return nil }
            return String(data: pretty, encoding: .utf8)
        }
    }
}
