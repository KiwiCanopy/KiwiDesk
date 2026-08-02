import KiwiDeskCore
import SwiftUI

/// Environment plumbing for the Shortcuts tab's override layer
/// (#55 phase 7): while editing a stored profile the tab shows
/// the RESOLVED layers (base + the profile's sparse override).
/// Rows equal to their base gui.json row are inherited and
/// render dimmed; rows that diverge are this profile's
/// overrides and render at full strength — the same
/// inherited/overridden affordance as the per-space layout
/// overrides (#17). nil = live editing, no affordance.
private struct KeybindingOverrideBaseKey: EnvironmentKey {
    static let defaultValue: [KeyBinding]? = nil
}

private struct KeybindingModeNameKey: EnvironmentKey {
    static let defaultValue = KeyLayer.defaultName
}

extension EnvironmentValues {
    /// The selected layer's base bindings while the Shortcuts
    /// tab edits a stored profile; nil during live editing.
    var keybindingOverrideBase: [KeyBinding]? {
        get { self[KeybindingOverrideBaseKey.self] }
        set { self[KeybindingOverrideBaseKey.self] = newValue }
    }

    /// Layer whose recorder rows are currently rendered. The
    /// live-apply seam uses it without threading another value
    /// through every intent-section wrapper.
    var keybindingLayerName: String {
        get { self[KeybindingModeNameKey.self] }
        set { self[KeybindingModeNameKey.self] = newValue }
    }
}

extension KeyBinding {
    /// Whether this row is inherited unchanged from `base` —
    /// SEMANTIC match (`sameAction`: combo + lua), so the GUI
    /// import classifier's display-only kind/label upgrades
    /// never render an untouched row as overridden. Always
    /// false outside override layer (`base == nil`).
    func isInherited(from base: [KeyBinding]?) -> Bool {
        base?.contains { $0.sameAction(as: self) } == true
    }
}

extension View {
    /// Dimmed when inherited, full strength when overridden
    /// or while editing live.
    func keybindingRowStyle(inherited: Bool) -> some View {
        opacity(inherited ? 0.55 : 1)
    }
}
