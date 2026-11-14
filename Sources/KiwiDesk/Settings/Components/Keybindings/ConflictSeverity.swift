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
/// WON by KiwiDesk, so the app loses it. ⌘Tab and ⌥⌘Esc, outside
/// the symbolic table, are macOS's too (#1275, 2026-10-10): dead,
/// and no setting switches them off. A leader on the input-source
/// chord wins it: macOS answers that one past the keyboard tap
/// (#3239, 2026-11-14).
enum ConflictSeverity: Equatable {
    /// A chord macOS answers first — a symbolic hotkey it has
    /// switched on, or ⌘Tab / ⌥⌘Esc: the row never fires.
    case dead(SystemShortcut)
    /// macOS holds the chord but has it switched off (the Zoom
    /// and Invert Colors families): the row works until the
    /// user turns that feature on.
    case dormant(SystemShortcut)
    /// A chord every app's menus carry: the row works and every
    /// app loses that item's shortcut while it is bound.
    case shadowsApps(SystemShortcut)
    /// A sequence's step key on a chord macOS answers: the key wins
    /// it while the sequence is open, macOS loses it then (#3173).
    case takesFromMacOS(SystemShortcut)
    /// A sequence's leader on a chord macOS answers only past the
    /// keyboard tap: the leader wins it, and macOS loses it while
    /// it is bound (#3239).
    case leaderTakesFromMacOS(SystemShortcut)
    /// Another row of the same layer holds the chord: one of the
    /// two fires, the other is silent.
    case duplicate(KeyBinding)
    /// Another row differs only in a modifier's side, and sides are
    /// not told apart (#2601 ▸ Ruling 5): one of the two fires, and
    /// the switch separates them.
    case sideCollapse(KeyBinding)
    /// Rows naming each side of this either-side row take every
    /// key from it (#3256): it never fires.
    case sidesTaken([KeyBinding])
    /// The chord string does not parse.
    case unrecognized

    /// The other row holding the chord, for a duplicate or a side
    /// collapse.
    var otherBinding: KeyBinding? {
        switch self {
        case .duplicate(let other), .sideCollapse(let other):
            return other
        case .sidesTaken(let takers):
            return takers.first
        default: return nil
        }
    }

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
            if conflict.binding.isSequence, shortcut.yieldsToKeyboardTap {
                return .leaderTakesFromMacOS(shortcut)
            }
            return shortcut.isUniversalAccelerator
                ? .shadowsApps(shortcut) : .dead(shortcut)
        case .otherBinding(let who):
            return .duplicate(who)
        case .sideCollapse(let who):
            return .sideCollapse(who)
        case .sidesTaken(let takers):
            return .sidesTaken(takers)
        case .unrecognized:
            return .unrecognized
        }
    }

    /// Whether the row cannot fire as things stand — the reading
    /// the loud row treatment keys on. A duplicate is not dead:
    /// one of its two rows works, and which one is the user's to
    /// settle by clearing the other.
    var isDead: Bool {
        switch self {
        case .dead, .sidesTaken: return true
        default: return false
        }
    }
}
