import SwiftUI

/// The sidebar's destinations (#68 §3.1): a two-group source
/// list that makes the profile/global scope split part of the
/// navigation itself — "This Profile" sections follow the
/// banner's edit target, "Whole App" sections are always live.
enum SettingsDestination: String, CaseIterable, Identifiable {
    // This Profile
    case spaces
    case layoutDefaults
    case monitors
    case appearance
    case behavior
    // Whole App
    case profiles
    case shortcuts
    case appRules
    case general

    var id: String { rawValue }

    static let thisProfile: [SettingsDestination] = [
        .spaces, .layoutDefaults, .monitors, .appearance,
        .behavior,
    ]
    static let wholeApp: [SettingsDestination] = [
        .profiles, .shortcuts, .appRules, .general,
    ]

    var title: String {
        switch self {
        case .spaces: return "Spaces"
        case .layoutDefaults: return "Layout Defaults"
        case .monitors: return "Monitors"
        case .appearance: return "Appearance"
        case .behavior: return "Behavior"
        case .profiles: return "Profiles"
        case .shortcuts: return "Shortcuts"
        case .appRules: return "App Rules"
        case .general: return "General"
        }
    }

    /// §6.1 — one glyph per destination, never reused across
    /// two sidebar items or another surface meaning something
    /// else (icons are vocabulary).
    var symbol: String {
        switch self {
        case .spaces: return "rectangle.split.3x1"
        case .layoutDefaults: return "slider.horizontal.3"
        case .monitors: return "display.2"
        case .appearance: return "paintbrush.fill"
        case .behavior: return "cursorarrow.motionlines"
        case .profiles: return "square.stack.3d.up"
        case .shortcuts: return "keyboard"
        case .appRules: return "app.badge.checkmark"
        case .general: return "gearshape"
        }
    }

    /// §6.1 — System-Settings-style tile colors, so the
    /// sidebar scans by color+shape before reading a label.
    var tint: Color {
        switch self {
        case .spaces: return .indigo
        case .layoutDefaults: return .teal
        case .monitors: return .blue
        case .appearance: return .purple
        case .behavior: return .orange
        case .profiles: return .green
        case .shortcuts:
            return Color(
                red: 0.35,
                green: 0.35,
                blue: 0.38
            )
        case .appRules: return .red
        case .general: return .gray
        }
    }

    /// Whether the destination is offered while a stored
    /// profile is being edited (#18): App Rules and the
    /// Advanced/About General section are global surfaces
    /// that a profile edit never writes.
    var visibleWhileEditingStoredProfile: Bool {
        switch self {
        case .appRules, .general: return false
        default: return true
        }
    }
}
