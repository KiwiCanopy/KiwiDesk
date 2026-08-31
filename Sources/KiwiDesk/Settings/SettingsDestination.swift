import KiwiDeskCore
import SwiftUI

/// Settings navigation destinations (#68, #678 turn 9).
enum SettingsDestination: String, CaseIterable, Identifiable {
    // This Profile
    case spaces
    case layoutDefaults
    case monitors
    case colors
    case advancedColors
    case gapsAndBorders
    case bars
    case behavior
    // Whole App
    case profiles
    case shortcuts
    case appRules
    case general

    var id: String { rawValue }

    /// Destinations scoped to the active profile (`SettingsSearchTests`,
    /// `HomeCardOrderTests`).
    static let thisProfile: [SettingsDestination] = [
        .spaces, .layoutDefaults, .monitors, .gapsAndBorders,
        .bars, .colors, .advancedColors, .behavior,
    ]
    /// Destinations scoped globally across the application.
    static let wholeApp: [SettingsDestination] = [
        .profiles, .shortcuts, .appRules, .general,
    ]

    @MainActor var title: String {
        switch self {
        case .spaces: return L("destination.spaces", "Spaces")
        case .layoutDefaults: return L("destination.layout", "Layout Defaults")
        case .monitors: return L("destination.monitors", "Monitors")
        case .colors:
            return L(
                "destination.colors",
                "Colors & Animations"
            )
        case .advancedColors:
            return L(
                "destination.advanced_colors",
                "Advanced Colors"
            )
        case .gapsAndBorders:
            return L("destination.gaps_borders", "Gaps & Borders")
        case .bars: return L("destination.bars", "Bars")
        case .behavior: return L("destination.behavior", "Behavior")
        case .profiles: return L("destination.profiles", "Profiles")
        case .shortcuts:
            return L("destination.shortcuts", "Shortcuts")
        case .appRules:
            return L("destination.app_rules", "App Rules")
        case .general: return L("destination.general", "General")
        }
    }

    /// SF Symbol icon name for navigation item (§6.1).
    var symbol: String {
        switch self {
        case .spaces: return "squares.below.rectangle"
        case .layoutDefaults: return "rectangle.3.group"
        case .monitors: return "display.2"
        case .colors: return "paintbrush.fill"
        case .advancedColors: return "paintpalette.fill"
        case .gapsAndBorders: return "square.dashed.inset.filled"
        case .bars: return "menubar.rectangle"
        case .behavior: return "cursorarrow.motionlines"
        case .profiles: return "square.stack.3d.up"
        case .shortcuts: return "keyboard"
        case .appRules: return "app.badge.checkmark"
        case .general: return "gearshape"
        }
    }

    /// Tile tint color for navigation item (§6.1, `SettingsThemeTokenTests`).
    var tint: Color {
        switch self {
        case .spaces: return .indigo
        case .layoutDefaults:
            return Color(red: 0.09, green: 0.47, blue: 0.53)
        case .monitors: return .blue
        case .colors: return .purple
        case .advancedColors:
            return Color(red: 0.38, green: 0.20, blue: 0.60)
        case .gapsAndBorders: return .brown
        case .bars: return .pink
        case .behavior: return .orange
        case .profiles:
            return SettingsTheme.accent
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

    /// Whether destination is visible when editing a stored profile
    /// (#18, #109).
    var visibleWhileEditingStoredProfile: Bool {
        self != .general
    }

    /// Whether destination toolbar displays profile context picker.
    var showsProfileContext: Bool {
        self != .general
    }

    /// Reachability predicate for profile editing mode (#18).
    func isReachable(editingStoredProfile: Bool) -> Bool {
        !editingStoredProfile
            || visibleWhileEditingStoredProfile
    }
}
