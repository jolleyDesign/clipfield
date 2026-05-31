import SwiftUI

/// UserDefaults keys for appearance settings (shared by views via @AppStorage
/// and by non-view code like Theme / OverlayController via direct reads).
enum AppearanceKeys {
    static let accent = "appearance.accent"
    static let colorScheme = "appearance.colorScheme"
    static let overlaySize = "appearance.overlaySize"
    static let showPreview = "appearance.showPreview"
    static let sidebarCollapsed = "appearance.sidebarCollapsed"
    static let sidebarWidth = "appearance.sidebarWidth"
    static let previewWidth = "appearance.previewWidth"
    static let contentWidth = "overlay.contentWidth"
    static let contentHeight = "overlay.contentHeight"
}

/// Selectable accent colors. `system` follows the macOS accent color.
enum AccentTheme: String, CaseIterable, Identifiable {
    case system, blue, purple, indigo, pink, red, orange, green, teal

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .system: return .accentColor
        case .blue: return .blue
        case .purple: return .purple
        case .indigo: return .indigo
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .green: return .green
        case .teal: return .teal
        }
    }

    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    static var current: AccentTheme {
        AccentTheme(rawValue: UserDefaults.standard.string(forKey: AppearanceKeys.accent) ?? "") ?? .system
    }
}

/// Light / Dark / follow-system appearance.
enum AppColorScheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    var swiftUI: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    static var current: AppColorScheme {
        AppColorScheme(rawValue: UserDefaults.standard.string(forKey: AppearanceKeys.colorScheme) ?? "") ?? .system
    }
}

/// Overlay panel dimensions (the inner card; the window adds a 30pt margin).
enum OverlaySize: String, CaseIterable, Identifiable {
    case compact, standard, large

    var id: String { rawValue }
    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    var card: CGSize {
        switch self {
        case .compact: return CGSize(width: 760, height: 480)
        case .standard: return CGSize(width: 880, height: 540)
        case .large: return CGSize(width: 1000, height: 620)
        }
    }

    static var current: OverlaySize {
        OverlaySize(rawValue: UserDefaults.standard.string(forKey: AppearanceKeys.overlaySize) ?? "") ?? .standard
    }
}
