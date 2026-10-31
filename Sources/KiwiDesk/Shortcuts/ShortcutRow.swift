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
    /// Draws KiwiDesk's own app icon — its Open Settings row
    /// (#2246).
    var ownApp = false
    /// Draws the pocket mark — the Pocket rows (#2446, #2675).
    var pocketMark = false
    var monospaced: Bool = false
    /// Trailing accessory glyph for non-default actions (#334).
    var accessoryIcon: String? = nil
    var accessoryHelp: String = ""
    /// Whether the action cannot run for a reason the user's
    /// HARDWARE owns (a Desktop whose screen is detached). The
    /// panel DIMS such a row rather than dropping it — the combo
    /// is still registered and blocks that chord, and hiding it
    /// breaks "no bound shortcut is ever invisible". NOT the
    /// Inactive band's case: an inactive Space shortcut still
    /// fires and recreates its Space; only Mission Control makes
    /// a Desktop (`NavCommand.unavailable`).
    var unavailable: Bool = false
    /// Where the row acts right now, drawn after its name
    /// (`NavCommand.detail`, #2792).
    var detail: String? = nil
    /// What the overview's fold reads off a row that may join
    /// others (#2312); nil for one that never folds.
    var fold: ShortcutFold.Tag? = nil
    /// A folded row's members, each with its own chord: a search
    /// that names one opens the fold to it (#2312).
    var members: [ShortcutRow] = []
    /// The label VoiceOver reads where the drawn one abbreviates,
    /// a folded range read as "1 to 3".
    var spokenLabel: String? = nil
}

/// Named subgroup of shortcut rows in the Controls band.
struct ShortcutSubgroup: Identifiable {
    let title: String
    var rows: [ShortcutRow]
    /// The built-in group a binding's `group` token names (#2544);
    /// nil for a group a binding made of its own.
    var group: ShortcutGroup? = nil
    var id: String { title }
}

/// Read-only shortcut reference representation for a key mode
/// (`docs/user-guide.md`, #820).
struct ShortcutsReference {
    var layerName: String
    var controls: [ShortcutSubgroup]
    /// Inactive space bindings shown under real names (#820).
    var inactive: [ShortcutRow] = []
    /// Rows whose Desktop no screen shows (`ShortcutRow.unavailable`),
    /// lifted out of their groups to the column's end; Settings
    /// dims the same rows in place, where they stay rebindable.
    var desktopAway: [ShortcutRow] = []
    var apps: [ShortcutRow]
    /// The groups bindings make of their own (#2544), after the
    /// built-in ones and before Custom, in first-named order.
    var groups: [ShortcutSubgroup] = []
    var custom: [ShortcutRow]

    /// Whether the reference contains no listable shortcuts.
    var isEmpty: Bool {
        controls.isEmpty && inactive.isEmpty && desktopAway.isEmpty
            && apps.isEmpty && groups.isEmpty && custom.isEmpty
    }
}
