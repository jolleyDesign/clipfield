import Foundation

/// The primary content type of a clipboard item. This drives the icon and the
/// kind of preview rendered. Finer-grained semantic categories (link, email,
/// phone, color, code, …) are layered on top as smart *tags* — see `SmartTag`.
enum ClipKind: String, Codable, CaseIterable, Sendable {
    case text
    case richText
    case link
    case image
    case file
    case color
    case email
    case phone
    case code
    case other

    var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .richText: return "doc.richtext"
        case .link: return "link"
        case .image: return "photo"
        case .file: return "doc"
        case .color: return "paintpalette"
        case .email: return "envelope"
        case .phone: return "phone"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .other: return "doc.on.clipboard"
        }
    }

    var label: String {
        switch self {
        case .text: return "Text"
        case .richText: return "Rich Text"
        case .link: return "Link"
        case .image: return "Image"
        case .file: return "File"
        case .color: return "Color"
        case .email: return "Email"
        case .phone: return "Phone"
        case .code: return "Code"
        case .other: return "Other"
        }
    }
}
