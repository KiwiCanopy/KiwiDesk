import Foundation
import KiwiDeskCore

/// Data representation of a shortcut reference row (`ComboSymbols`).
struct ShortcutRow: Identifiable {
    let id: String
    let label: String
    let combo: String
    var icon: String? = nil
    var bundleID: String? = nil
    /// App Font ligature name overriding bundle icon (#294).
    var glyph: String? = nil
    var monospaced: Bool = false
    /// Trailing accessory glyph for non-default actions (#334).
    var accessoryIcon: String? = nil
    var accessoryHelp: String = ""
    /// Whether the action is currently hardware-unavailable
    /// (`NavCommand.unavailable`).
    var unavailable: Bool = false
}

/// Named subgroup of shortcut rows in the Controls band.
struct ShortcutSubgroup: Identifiable {
    let title: String
    let rows: [ShortcutRow]
    var id: String { title }
}

/// Read-only shortcut reference representation for a key mode
/// (`docs/user-guide.md`, #820).
struct ShortcutsReference {
    var layerName: String
    var controls: [ShortcutSubgroup]
    /// Inactive space bindings shown under real names (#820).
    var inactive: [ShortcutRow] = []
    var apps: [ShortcutRow]
    var custom: [ShortcutRow]

    /// Whether the reference contains no listable shortcuts.
    var isEmpty: Bool {
        controls.isEmpty && inactive.isEmpty && apps.isEmpty
            && custom.isEmpty
    }
}
