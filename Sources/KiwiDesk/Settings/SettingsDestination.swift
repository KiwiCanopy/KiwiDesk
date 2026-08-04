import KiwiDeskCore
import SwiftUI

/// The navigation identities (#68 §3.1 → #678 turn 9): one case
/// per area screen, fronted by a Home card. The two groups make
/// the profile/global scope split part of the navigation itself
/// — "This Profile" areas follow the header's edit target,
/// "Whole App" areas are always live.
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

    /// Advanced Colors sits DIRECTLY after its Simple twin, so
    /// the pair reads as a family wherever this order surfaces
    /// (the Power-User grid keeps both; search lists them
    /// adjacent).
    ///
    /// The pair sits AFTER the things it paints, and the order
    /// is load-bearing beyond taste: search returns one hit per
    /// destination in this order, so a colour page listed above
    /// Bars would answer "App Bar" with a grid of swatches
    /// instead of with the App Bar's own card
    /// (`SidebarSearchAnchorTests`). You arrive at colour having
    /// noticed something on a surface you already know.
    /// (The GRID's own order is `HomeCardOrder`'s; only set
    /// membership is shared — `HomeCardOrderTests` pins it.)
    static let thisProfile: [SettingsDestination] = [
        .spaces, .layoutDefaults, .monitors, .gapsAndBorders,
        .bars, .colors, .advancedColors, .behavior,
    ]
    static let wholeApp: [SettingsDestination] = [
        .profiles, .shortcuts, .appRules, .general,
    ]

    @MainActor var title: String {
        switch self {
        case .spaces: return L("destination.spaces", "Spaces")
        case .layoutDefaults: return L("destination.layout", "Layout Defaults")
        case .monitors: return L("destination.monitors", "Monitors")
        case .colors:
            return L("destination.colors", "Colors & Motion")
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

    /// §6.1 — one glyph per destination, never reused across
    /// two sidebar items or another surface meaning something
    /// else (icons are vocabulary).
    var symbol: String {
        switch self {
        case .spaces: return "squares.below.rectangle"
        case .layoutDefaults: return "rectangle.3.group"
        case .monitors: return "display.2"
        // The colour pair reads as a family — one paint glyph
        // each, the deeper one on the deeper page.
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

    /// §6.1 — System-Settings-style tile colors, so the
    /// sidebar scans by color+shape before reading a label.
    var tint: Color {
        switch self {
        case .spaces: return .indigo
        // Deeper teal/green than the system defaults: the
        // bright `.teal`/`.green` washed the white glyph out.
        case .layoutDefaults:
            // One of the varied per-section icon tints (System
            // Settings style), not a brand hue.
            return Color(red: 0.09, green: 0.47, blue: 0.53)
        case .monitors: return .blue
        // Colours & Motion inherits Appearance's purple with its
        // meaning; its Nerd twin takes a deeper violet, so the
        // pairing is legible by hue before either label is read.
        case .colors: return .purple
        case .advancedColors:
            return Color(red: 0.38, green: 0.20, blue: 0.60)
        case .gapsAndBorders: return .brown
        case .bars: return .pink
        case .behavior: return .orange
        case .profiles:
            // KiwiCanopy kiwi green #8DB354 as RGB floats (was
            // forest #298747) — keep in sync with the brand green
            // if it shifts; this literal isn't derived from it.
            return Color(red: 0.553, green: 0.702, blue: 0.329)
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
    /// profile is being edited (#18): only the Advanced/About
    /// General section is a global surface a profile edit
    /// never writes. App Rules joined the editable set when
    /// its Space facet grew a per-profile override (#109) —
    /// the Float facet stays global and renders disabled
    /// there.
    var visibleWhileEditingStoredProfile: Bool {
        self != .general
    }

    /// Whether the profile edit-target header (the toolbar
    /// picker + the status strip) is shown for this
    /// destination. Only General is truly profile-agnostic
    /// (About + the config-file tools).
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
