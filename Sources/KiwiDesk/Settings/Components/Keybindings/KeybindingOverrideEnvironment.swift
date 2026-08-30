import KiwiDeskCore
import SwiftUI

/// Environment keys for Shortcuts tab profile override rendering (#55, #17).
private struct KeybindingOverrideBaseKey: EnvironmentKey {
    static let defaultValue: [KeyBinding]? = nil
}

private struct KeybindingLayerNameKey: EnvironmentKey {
    static let defaultValue = KeyLayer.defaultName
}

extension EnvironmentValues {
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
    /// Applies dimmed styling and accessibility hint for inherited/unavailable
    /// shortcut rows
    /// (#678, #830, #818).
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
