import Foundation

/// Conflict detection across keybinding layers (#96).
public enum KeybindingConflicts {
    /// Whether any row in layer contains a conflict.
    public static func hasAny(
        _ bindings: [KeyBinding],
        distinguishingSides: Bool = false
    ) -> Bool {
        bindings.contains { binding in
            conflict(
                for: binding,
                in: bindings,
                distinguishingSides: distinguishingSides
            ) != nil
        }
    }

    /// Whether any layer contains conflicting keybindings.
    public static func hasAnyAcrossLayers(
        _ layers: [KeyLayer],
        distinguishingSides: Bool = false
    ) -> Bool {
        layers.contains {
            hasAny($0.bindings, distinguishingSides: distinguishingSides)
        }
    }

    /// Structured conflicts across all layers.
    public static func conflicts(
        in layers: [KeyLayer],
        distinguishingSides: Bool = false
    ) -> [Conflict] {
        layers.flatMap { layer in
            layer.bindings.compactMap { binding in
                conflict(
                    for: binding,
                    in: layer.bindings,
                    distinguishingSides: distinguishingSides
                )
            }
        }
    }

    /// Evaluates conflict for a single keybinding (#96,
    /// `SystemShortcuts.map`). `distinguishingSides` is the Mac's
    /// switch (#2601): on, `lcmd+h` beside `rcmd+h` is two
    /// shortcuts; off, the two collapse onto one Carbon chord.
    public static func conflict(
        for binding: KeyBinding,
        in bindings: [KeyBinding],
        distinguishingSides: Bool = false
    ) -> Conflict? {
        guard !binding.combo.isEmpty else { return nil }
        guard let parsed = KeyCombo.parse(binding.combo) else {
            return Conflict(binding: binding, target: .unrecognized)
        }
        // Compared as registered: a held Hyper row IS its bare
        // chord (#1870), so `hyper+cmd+space` meets Spotlight, and
        // a sided row its either-side chord, as macOS fires it.
        let combo = parsed.registered
        for other in bindings
        where other.id != binding.id && !other.combo.isEmpty {
            guard let otherCombo = KeyCombo.parse(other.combo)
            else { continue }
            guard otherCombo.registered == combo else { continue }
            let sided =
                parsed.modifiers.isSided
                || otherCombo.modifiers.isSided
            if !sided || parsed == otherCombo {
                return Conflict(
                    binding: binding,
                    target: .otherBinding(other)
                )
            }
            if !distinguishingSides {
                return Conflict(
                    binding: binding,
                    target: .sideCollapse(other)
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
        /// Two shortcuts that differ only in a modifier's side,
        /// read as one while sides are not told apart (#2601).
        case sideCollapse(KeyBinding)
        case unrecognized
    }

    public let binding: KeyBinding
    public let target: Target
}
