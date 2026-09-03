import KiwiDeskCore
import SwiftUI

/// What a conflict COSTS the row (#1126) — the reading every row
/// surface narrates and draws from. Core names the collision
/// (`Conflict`, #96); whether macOS currently answers the chord is
/// machine state the GUI reads (#1105), so the severity is derived
/// here, at the boundary, never in `KeybindingConflicts`.
///
/// The precedence is measured, not folklore (#1126, 2026-09-03):
/// an ENABLED symbolic hotkey is answered by macOS before the
/// binding hears the press, so that row never fires; a layer is
/// one `[KeyCombo: ref]` table, so of two rows on one chord
/// exactly one fires; a chord every app's menus carry (⌘W) is
/// WON by KiwiDesk, so the app loses it. ⌘Tab and ⌥⌘Esc have no
/// measured precedence yet, so they stay a collision.
enum ConflictSeverity: Equatable {
    /// A symbolic hotkey macOS has switched on: the press goes
    /// to macOS and the row never fires.
    case dead(SystemShortcut)
    /// macOS holds the chord but has it switched off (the Zoom
    /// and Invert Colors families): the row works until the
    /// user turns that feature on.
    case dormant(SystemShortcut)
    /// A chord every app's menus carry: the row works and every
    /// app loses that item's shortcut while it is bound.
    case shadowsApps(SystemShortcut)
    /// A system-level chord outside the symbolic table (⌘Tab,
    /// ⌥⌘Esc) — who wins the press is unmeasured (#1126).
    case reserved(SystemShortcut)
    /// Another row of the same layer holds the chord: one of the
    /// two fires, the other is silent.
    case duplicate(String)
    /// The chord string does not parse.
    case unrecognized

    /// The reading of `conflict` on a machine whose switched-off
    /// system shortcuts are `disabled`
    /// (`SettingsModel.disabledSystemShortcuts()`).
    static func of(
        _ conflict: Conflict,
        disabled: Set<SystemShortcut>
    ) -> ConflictSeverity {
        switch conflict.target {
        case .systemShortcut(let shortcut):
            if disabled.contains(shortcut) { return .dormant(shortcut) }
            if shortcut.symbolicHotkey != nil { return .dead(shortcut) }
            return shortcut.isUniversalAccelerator
                ? .shadowsApps(shortcut) : .reserved(shortcut)
        case .otherBinding(let who):
            return .duplicate(who)
        case .unrecognized:
            return .unrecognized
        }
    }

    /// Whether the row cannot fire as things stand — the reading
    /// the loud row treatment keys on. A duplicate is not dead:
    /// one of its two rows works, and which one is the user's to
    /// settle by clearing the other.
    var isDead: Bool {
        if case .dead = self { return true }
        return false
    }
}
