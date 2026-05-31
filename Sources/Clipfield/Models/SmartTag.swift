import Foundation

/// Semantic categories auto-detected for a clip's content. Stored on `ClipItem`
/// as an array of raw values so they can be used as search/filter chips.
enum SmartTag: String, Codable, CaseIterable, Sendable {
    case link
    case email
    case phone
    case address
    case date
    case color
    case code
    case number
    case image
    case file

    var systemImage: String {
        switch self {
        case .link: return "link"
        case .email: return "envelope"
        case .phone: return "phone"
        case .address: return "mappin.and.ellipse"
        case .date: return "calendar"
        case .color: return "paintpalette"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .number: return "number"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    var label: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}
