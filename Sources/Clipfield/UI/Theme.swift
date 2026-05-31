import SwiftUI

/// Shared visual constants and helpers for a cohesive look across the app.
enum Theme {
    static let panelCornerRadius: CGFloat = 18
    static let rowCornerRadius: CGFloat = 10

    /// The user's chosen accent (falls back to the system accent).
    static var accent: Color { AccentTheme.current.color }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Spring used for selection movement and chip/sidebar highlights.
    static let selectionSpring = Animation.spring(response: 0.28, dampingFraction: 0.82)
    /// Spring used to present/toggle the overlay's inline prompts (editor, fill,
    /// new-folder, snippet editor, shortcuts sheet).
    static let promptSpring = Animation.spring(response: 0.3, dampingFraction: 0.8)
}

extension ClipKind {
    /// Accent color used for this kind's badge and previews.
    var tint: Color {
        switch self {
        case .text: return .gray
        case .richText: return .indigo
        case .link: return .blue
        case .image: return .purple
        case .file: return .gray
        case .color: return .pink
        case .email: return .green
        case .phone: return .teal
        case .code: return .orange
        case .other: return .gray
        }
    }
}

extension Color {
    /// Parses `#RGB`, `#RRGGBB`, or `#RRGGBBAA` (with or without leading `#`).
    init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard let value = UInt64(hex, radix: 16) else { return nil }

        let r, g, b, a: Double
        switch hex.count {
        case 3:
            r = Double((value >> 8) & 0xF) / 15
            g = Double((value >> 4) & 0xF) / 15
            b = Double(value & 0xF) / 15
            a = 1
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            return nil
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
