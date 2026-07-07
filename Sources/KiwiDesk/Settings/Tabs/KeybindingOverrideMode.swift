import KiwiDeskCore
import SwiftUI

/// Environment plumbing for the Shortcuts tab's override mode
/// (#55 phase 7): while editing a stored profile the tab shows
/// the RESOLVED modes (base + the profile's sparse override).
/// Rows equal to their base gui.json row are inherited and
/// render dimmed; rows that diverge are this profile's
/// overrides and render at full strength — the same
/// inherited/overridden affordance as the per-space layout
/// overrides (#17). nil = live editing, no affordance.
private struct KeybindingOverrideBaseKey: EnvironmentKey {
    static let defaultValue: [KeyBinding]? = nil
}

extension EnvironmentValues {
    /// The selected mode's base bindings while the Shortcuts
    /// tab edits a stored profile; nil during live editing.
    var keybindingOverrideBase: [KeyBinding]? {
        get { self[KeybindingOverrideBaseKey.self] }
        set { self[KeybindingOverrideBaseKey.self] = newValue }
    }
}

extension KeyBinding {
    /// Whether this row is inherited unchanged from `base`
    /// (id is excluded from equality, so a save/load cycle
    /// does not break the match). Always false outside
    /// override mode (`base == nil`).
    func isInherited(from base: [KeyBinding]?) -> Bool {
        base?.contains(self) == true
    }
}

extension View {
    /// Dimmed when inherited, full strength when overridden
    /// or while editing live.
    func keybindingRowStyle(inherited: Bool) -> some View {
        opacity(inherited ? 0.55 : 1)
    }
}
