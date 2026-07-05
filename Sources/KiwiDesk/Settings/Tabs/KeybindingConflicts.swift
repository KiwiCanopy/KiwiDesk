import KiwiDeskCore

/// Conflict detection for the keybindings tab. Comparisons run
/// on the parsed `KeyCombo` (key code + modifiers), so they are
/// independent of how a combo was spelled (05_GUI_Concept §2,
/// Tab 5).
enum KeybindingConflicts {
    /// A tooltip describing the conflict on this row, or nil if
    /// the combo is empty, invalid-but-empty, or unique.
    static func text(
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
        if let system = KeybindingCatalog.systemShortcuts[combo] {
            return "Conflicts with macOS: \(system)"
        }
        return nil
    }

    /// Whether any row in the set carries a conflict — drives
    /// the one-time notification on config load.
    static func hasAny(_ bindings: [KeyBinding]) -> Bool {
        bindings.contains { binding in
            text(for: binding, in: bindings) != nil
        }
    }

    /// Whether any mode's bindings carry a conflict. Modes are
    /// independent keymaps (only one is active at a time), so
    /// each is checked against its own rows only.
    static func hasAny(in modes: [KeyMode]) -> Bool {
        modes.contains { hasAny($0.bindings) }
    }
}
