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
        guard let combo = KeyCombo.parse(binding.combo) else {
            return Conflict(binding: binding, target: .unrecognized)
        }
        for other in bindings
        where other.id != binding.id && !other.combo.isEmpty {
            guard let otherCombo = KeyCombo.parse(other.combo)
            else { continue }
            if otherCombo == combo {
                return Conflict(
                    binding: binding,
                    target: .otherBinding(other)
                )
            }
        }
        if let system = SystemShortcuts.map[combo] {
            return Conflict(
                binding: binding,
                target: .systemShortcut(system)
            )
        }
        return nil
    }

    /// Actionable conflicts excluding system shortcuts macOS has
    /// switched OFF (`⌃⌥⌘8`, #1094/#1105). The set is machine
    /// state, so the caller reads it — the GUI's one accessor is
    /// `SettingsModel.actionableConflicts()`, which threads the
    /// live `com.apple.symbolichotkeys` read; this type stays a
    /// pure description of chords (#96 split).
    public static func actionable(
        in layers: [KeyLayer],
        disabledSystemShortcuts: Set<SystemShortcut>
    ) -> [Conflict] {
        conflicts(in: layers).filter { conflict in
            guard case .systemShortcut(let s) = conflict.target
            else { return true }
            return !disabledSystemShortcuts.contains(s)
        }
    }
}

/// Structured representation of a keybinding conflict (`SystemShortcut`, #96).
/// It carries the BINDINGS, never a name: the GUI names each side
/// the way its row does (`KeybindingCatalog.localizedName`, #2116).
public struct Conflict: Equatable, Sendable {
    /// Conflict category and target details.
    public enum Target: Equatable, Sendable {
        case systemShortcut(SystemShortcut)
        case otherBinding(KeyBinding)
        case unrecognized
    }

    public let binding: KeyBinding
    public let target: Target
}
