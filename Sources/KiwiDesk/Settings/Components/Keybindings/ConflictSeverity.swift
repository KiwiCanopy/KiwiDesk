import KiwiDeskCore
import SwiftUI

/// What a conflict COSTS the row (#1126) — the reading every row
/// surface narrates and draws from. Core names the collision
/// (`Conflict`, #96); whether macOS currently answers the chord is
/// machine state the GUI reads (#1105), so the severity is derived
/// here, at the boundary, never in `KeybindingConflicts`.
///
/// The precedence is measured, not folklore
/// (`docs/design-decisions.md` ▸ "Size is not a positional
/// verb"): `RegisterEventHotKey` FAILS against a live macOS
/// chord, so that row never fires; a layer is one `[KeyCombo:
/// ref]` table, so of two rows on one chord exactly one fires.
enum ConflictSeverity: Equatable {
    /// macOS holds the chord and has it switched on: the
    /// registration is refused and the row never fires.
    case dead(SystemShortcut)
    /// macOS holds the chord but has it switched off (the Zoom
    /// and Invert Colors families): the row works until the
    /// user turns that feature on.
    case dormant(SystemShortcut)
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
            return disabled.contains(shortcut)
                ? .dormant(shortcut) : .dead(shortcut)
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

/// The switched-off system shortcuts, read ONCE per section
/// render and handed down (#1105 asked for one read per surface,
/// not one per row). Defaults empty — a row rendered outside the
/// Shortcuts section reads every register chord as live, which
/// is the shipped-default reading for a host that has toggled
/// nothing.
private struct DisabledSystemShortcutsKey: EnvironmentKey {
    static let defaultValue: Set<SystemShortcut> = []
}

extension EnvironmentValues {
    var disabledSystemShortcuts: Set<SystemShortcut> {
        get { self[DisabledSystemShortcutsKey.self] }
        set { self[DisabledSystemShortcutsKey.self] = newValue }
    }
}
