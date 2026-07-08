import KiwiDeskCore
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

    @MainActor var title: String {
        switch self {
        case .spaces: return L("sidebar.spaces", "Spaces")
        case .layoutDefaults: return L("sidebar.layout", "Layout")
        case .monitors: return L("sidebar.monitors", "Monitors")
        case .appearance:
            return L("sidebar.appearance", "Appearance")
        case .behavior: return L("sidebar.behavior", "Behavior")
        case .profiles: return L("sidebar.profiles", "Profiles")
        case .shortcuts:
            return L("sidebar.shortcuts", "Shortcuts")
        case .appRules:
            return L("sidebar.app_rules", "App Rules")
        case .general: return L("sidebar.general", "General")
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
        // Deeper teal/green than the system defaults: the
        // bright `.teal`/`.green` washed the white glyph out.
        case .layoutDefaults:
            return Color(red: 0.09, green: 0.47, blue: 0.53)
        case .monitors: return .blue
        case .appearance: return .purple
        case .behavior: return .orange
        case .profiles:
            return Color(red: 0.16, green: 0.53, blue: 0.28)
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

    /// Whether the profile edit-target header (the toolbar
    /// picker + the status strip) is shown for this
    /// destination. Only General is truly profile-agnostic
    /// (About + the config-file tools). App Rules is shown
    /// too — its rules assign apps to spaces, and spaces are
    /// profile-scoped, so the picker names which profile's
    /// spaces a rule targets — so this is NOT the same set as
    /// `visibleWhileEditingStoredProfile`.
    var showsProfileContext: Bool {
        self != .general
    }

    /// The one reachability predicate all #18 enforcement
    /// points share (sidebar offer, selection repair, navigate
    /// guard) — one polarity, no hand-negated copies.
    func isReachable(editingStoredProfile: Bool) -> Bool {
        !editingStoredProfile
            || visibleWhileEditingStoredProfile
    }
}
