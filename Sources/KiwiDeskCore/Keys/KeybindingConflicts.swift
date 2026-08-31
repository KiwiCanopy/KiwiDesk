import Foundation

/// Conflict detection across keybinding layers (#96).
public enum KeybindingConflicts {
    /// Whether any row in layer contains a conflict.
    public static func hasAny(_ bindings: [KeyBinding]) -> Bool {
        bindings.contains { binding in
            conflict(for: binding, in: bindings) != nil
        }
    }

    /// Whether any layer contains conflicting keybindings.
    public static func hasAnyAcrossLayers(
        _ layers: [KeyLayer]
    ) -> Bool {
        layers.contains { hasAny($0.bindings) }
    }

    /// Structured conflicts across all layers.
    public static func conflicts(
        in layers: [KeyLayer]
    ) -> [Conflict] {
        layers.flatMap { layer in
            layer.bindings.compactMap { binding in
                conflict(for: binding, in: layer.bindings)
            }
        }
    }

    /// Evaluates conflict for a single keybinding (#96,
    /// `SystemShortcuts.map`).
    public static func conflict(
        for binding: KeyBinding,
        in bindings: [KeyBinding]
    ) -> Conflict? {
        guard !binding.combo.isEmpty else { return nil }
        let name =
            binding.label.isEmpty ? binding.combo : binding.label
        guard let combo = KeyCombo.parse(binding.combo) else {
            return Conflict(name: name, target: .unrecognized)
        }
        for other in bindings
        where other.id != binding.id && !other.combo.isEmpty {
            guard let otherCombo = KeyCombo.parse(other.combo)
            else { continue }
            if otherCombo == combo {
                let who =
                    other.label.isEmpty
                    ? other.combo : other.label
                return Conflict(
                    name: name,
                    target: .otherBinding(who)
                )
            }
        }
        if let system = SystemShortcuts.map[combo] {
            return Conflict(
                name: name,
                target: .systemShortcut(system)
            )
        }
        return nil
    }

    /// Actionable conflicts excluding shipped-disabled system
    /// shortcuts (`⌃⌥⌘8`, #1094; #1105 replaces the shipped-state
    /// read with a live one). One accessor rather than a filter
    /// per surface: there are three aggregate readers and the
    /// first fix wired only one of them.
    public static func actionable(
        in layers: [KeyLayer]
    ) -> [Conflict] {
        conflicts(in: layers).filter { conflict in
            guard case .systemShortcut(let s) = conflict.target
            else { return true }
            return !s.shipsDisabled
        }
    }
}

/// Structured representation of a keybinding conflict (`SystemShortcut`, #96).
public struct Conflict: Equatable, Sendable {
    /// Conflict category and target details.
    public enum Target: Equatable, Sendable {
        case systemShortcut(SystemShortcut)
        case otherBinding(String)
        case unrecognized
    }

    public let name: String
    public let target: Target
}
