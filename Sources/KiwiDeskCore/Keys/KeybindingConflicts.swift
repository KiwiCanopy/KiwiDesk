import Foundation

/// Conflict detection for the keybindings tab. Comparisons run
/// on the parsed `KeyCombo` (key code + modifiers), so they are
/// independent of how a combo was spelled (05_GUI_Concept §2,
/// Tab 5). Lives in Core (not the GUI target) so it can be
/// evaluated at app launch, before the Settings window exists.
public enum KeybindingConflicts {
    /// A tooltip describing the conflict on this row, or nil if
    /// the combo is empty, invalid-but-empty, or unique.
    public static func text(
        for binding: KeyBinding,
        in bindings: [KeyBinding]
    ) -> String? {
        guard !binding.combo.isEmpty else { return nil }
        guard let combo = KeyCombo.parse(binding.combo) else {
            return "Not a recognized shortcut."
        }
        for other in bindings
        where other.id != binding.id && !other.combo.isEmpty {
            guard let otherCombo = KeyCombo.parse(other.combo)
            else { continue }
            if otherCombo == combo {
                let who =
                    other.label.isEmpty
                    ? other.combo : other.label
                return "Already bound in this mode: \(who)"
            }
        }
        if let system = SystemShortcuts.map[combo] {
            return "Conflicts with macOS: \(system)"
        }
        return nil
    }

    /// Whether any row in the set carries a conflict.
    public static func hasAny(_ bindings: [KeyBinding]) -> Bool {
        bindings.contains { binding in
            text(for: binding, in: bindings) != nil
        }
    }

    /// Whether any mode's bindings carry a conflict — drives
    /// the one-time notification on config load. Modes are
    /// independent keymaps (only one is active at a time), so
    /// each is checked against its own rows only.
    public static func hasAnyAcrossModes(
        _ modes: [KeyMode]
    ) -> Bool {
        modes.contains { hasAny($0.bindings) }
    }
}
