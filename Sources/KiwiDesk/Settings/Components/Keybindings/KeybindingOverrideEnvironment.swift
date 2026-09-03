import KiwiDeskCore
import SwiftUI

/// Environment keys for Shortcuts tab profile override rendering (#55, #17).
private struct KeybindingOverrideBaseKey: EnvironmentKey {
    static let defaultValue: [KeyBinding]? = nil
}

private struct KeybindingLayerNameKey: EnvironmentKey {
    static let defaultValue = KeyLayer.defaultName
}

/// The switched-off system shortcuts (#1105), read ONCE per
/// section render and handed down — never one read per row.
///
/// The empty default is NOT the shipped reading: six chords ship
/// disabled, so a row rendered outside `ShortcutsSection` would
/// over-report `.dead`. What keeps that unreachable is that
/// every recorder mount descends from the one wiring site, which
/// `ConflictRowTreatmentTests` pins (#1126).
private struct DisabledSystemShortcutsKey: EnvironmentKey {
    static let defaultValue: Set<SystemShortcut> = []
}

extension EnvironmentValues {
    var disabledSystemShortcuts: Set<SystemShortcut> {
        get { self[DisabledSystemShortcutsKey.self] }
        set { self[DisabledSystemShortcutsKey.self] = newValue }
    }

    /// Base bindings for selected layer during profile override editing; nil
    /// during live editing.
    var keybindingOverrideBase: [KeyBinding]? {
        get { self[KeybindingOverrideBaseKey.self] }
        set { self[KeybindingOverrideBaseKey.self] = newValue }
    }

    /// Name of layer whose keybindings are currently rendered.
    var keybindingLayerName: String {
        get { self[KeybindingLayerNameKey.self] }
        set { self[KeybindingLayerNameKey.self] = newValue }
    }
}

extension KeyBinding {
    /// Whether this binding is semantically identical to a base binding (#55).
    func isInherited(from base: [KeyBinding]?) -> Bool {
        base?.contains { $0.sameAction(as: self) } == true
    }
}

extension View {
    /// Applies dimmed styling and a spoken hint for
    /// inherited/unavailable rows (#678 turn 20a rule 3). Both
    /// states stay EDITABLE — dim, never disable. The hint names
    /// no control, deliberately, against #830's table: the label
    /// it quoted renders only while `combo.isEmpty`, so the
    /// sentence named a word not on screen for the one row it
    /// describes — when a control's label is not visible, the fix
    /// is to stop naming it, not a better interpolation (#818's
    /// boundary). Unverified whether a container hint reaches the
    /// control inside; kept because the worse case here is an
    /// inert hint — where `GreyOut`'s was DELETING shipped hints,
    /// which is why that one was backed out. Confirm both in one
    /// Accessibility Inspector pass.
    func keybindingRowStyle(
        inherited: Bool,
        unavailable: String? = nil
    ) -> some View {
        opacity(inherited || unavailable != nil ? 0.55 : 1)
            .accessibilityHint(
                unavailable
                    ?? (inherited
                        ? L(
                            "shortcuts.row.inherited.axhint",
                            "Inherited from the base shortcuts. "
                                + "Set a key here to override it."
                        )
                        : "")
            )
    }
}
