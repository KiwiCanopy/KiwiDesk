import Foundation
import KiwiDeskCore

/// A built-in shortcut group's title in the user's language
/// (#2544): the one place the GUI names it, read by KiwiHub's bands
/// and Settings' shortcut group field alike.
extension ShortcutGroup {
    @MainActor var title: String {
        switch self {
        case .focus: L("shortcuts.section.focus", "Focus")
        case .moveWindows:
            L("shortcuts.section.move_windows", "Move windows")
        case .layout: L("shortcuts.section.layout", "Layout")
        case .sizeFloat: L("shortcuts.section.size_float", "Size & float")
        case .kiwivision: L("destination.kiwivision", "KiwiVision")
        case .kiwishelf: L("bars.switch.kiwishelf", "KiwiShelf")
        case .apps: L("shortcuts.panel.apps", "Apps")
        }
    }

    /// The word for the user's own shortcuts: KiwiHub's band for
    /// them and the Shortcuts page's Personal part (#3184), one
    /// string so the two never differ.
    @MainActor static var personalTitle: String {
        L("shortcuts.panel.custom", "Personal")
    }
}
