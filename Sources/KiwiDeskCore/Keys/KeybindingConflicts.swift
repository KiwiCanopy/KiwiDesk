import Foundation

/// Conflict detection across keybinding layers (#96).
public enum KeybindingConflicts {
    /// Whether any row in layer contains a conflict.
    public static func hasAny(
        _ bindings: [KeyBinding],
        distinguishingSides: Bool
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
        distinguishingSides: Bool
    ) -> Bool {
        layers.contains {
            hasAny($0.bindings, distinguishingSides: distinguishingSides)
        }
    }

    /// Structured conflicts across all layers.
    public static func conflicts(
        in layers: [KeyLayer],
        distinguishingSides: Bool
    ) -> [Conflict] {
        layers.flatMap { layer in
            let rows = layer.bindings
            // Keyed by id, so a layer repeating one is judged by row.
            guard Set(rows.map(\.id)).count == rows.count else {
                return rows.compactMap {
                    conflict(
                        for: $0,
                        in: rows,
                        distinguishingSides: distinguishingSides
                    )
                }
            }
            let byID = rowConflicts(
                of: rows,
                distinguishingSides: distinguishingSides
            )
            return rows.compactMap { byID[$0.id] }
        }
    }

    /// Evaluates conflict for a single keybinding (#96,
    /// `SystemShortcuts.map`). `distinguishingSides` is the Mac's
    /// switch (#2601): on, `lcmd+h` beside `rcmd+h` is two
    /// shortcuts; off, the two collapse onto one Carbon chord.
    public static func conflict(
        for binding: KeyBinding,
        in bindings: [KeyBinding],
        distinguishingSides: Bool
    ) -> Conflict? {
        guard !binding.combo.isEmpty else { return nil }
        guard let parsed = KeyCombo.parse(binding.combo) else {
            return Conflict(binding: binding, target: .unrecognized)
        }
        let rivals = bindings.lazy
            .filter { !$0.combo.isEmpty }
            .compactMap { other in
                KeyCombo.parse(other.combo).map { (other, $0) }
            }
        return conflict(
            for: binding,
            parsed: parsed,
            among: rivals,
            distinguishingSides: distinguishingSides
        )
    }

    /// The rule over rows already parsed, in their layer's order.
    static func conflict(
        for binding: KeyBinding,
        parsed: KeyCombo,
        among rivals: some Sequence<(KeyBinding, KeyCombo)>,
        distinguishingSides: Bool
    ) -> Conflict? {
        // Compared as registered: a held Hyper row IS its bare
        // chord (#1870), so `hyper+cmd+space` meets Spotlight, and
        // a sided row its either-side chord, as macOS fires it.
        let combo = parsed.registered
        // `rowConflicts` hands only rows of the same registered
        // chord, so a clause matching across chords breaks it
        // (`LayerConflictsTests`).
        let rivals = Array(rivals)
        for (other, otherCombo) in rivals where other.id != binding.id {
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
            // A tap reads its side whatever the switch (#1872).
            if !distinguishingSides, !parsed.isTap {
                return Conflict(
                    binding: binding,
                    target: .sideCollapse(other)
                )
            }
        }
        // Every key taken: it never fires, counted (#3256); one
        // taker is a plain clash, flagged on both rows as a
        // duplicate is (#3278). One side taken is precedence.
        if let reach = sideReach(
            for: binding,
            parsed: parsed,
            among: rivals,
            distinguishingSides: distinguishingSides
        ), reach.isDead {
            let takers = reach.takers
            return Conflict(
                binding: binding,
                target: takers.count == 1
                    ? .otherBinding(takers[0]) : .sidesTaken(takers)
            )
        }
        for (other, otherCombo) in rivals
        where other.id != binding.id && otherCombo.registered == combo {
            if let reach = sideReach(
                for: other,
                parsed: otherCombo,
                among: rivals,
                distinguishingSides: distinguishingSides
            ), reach.isDead, reach.takers.map(\.id) == [binding.id] {
                return Conflict(binding: binding, target: .otherBinding(other))
            }
        }
        if let system = SystemShortcuts.map[combo] {
            let path = pressPath(
                of: binding,
                among: rivals,
                distinguishingSides: distinguishingSides
            )
            return Conflict(
                binding: binding,
                target: .systemShortcut(system, path)
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
        disabledSystemShortcuts: Set<SystemShortcut>,
        distinguishingSides: Bool
    ) -> [Conflict] {
        conflicts(
            in: layers,
            distinguishingSides: distinguishingSides
        ).filter { conflict in
            guard case .systemShortcut(let s, _) = conflict.target
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
        /// A chord macOS holds, and the door the row's press comes
        /// through, which decides who wins it (#3311).
        case systemShortcut(SystemShortcut, PressPath)
        case otherBinding(KeyBinding)
        /// Two shortcuts that differ only in a modifier's side,
        /// read as one while sides are not told apart (#2601).
        case sideCollapse(KeyBinding)
        /// Rows naming each side of this either-side row take
        /// every key from it (#3256): each row once, in the order
        /// they take them. At least two, because a single row taking
        /// every form is the same chord, which the duplicate arm
        /// answers first; a surface naming them names the first two.
        case sidesTaken([KeyBinding])
        case unrecognized
    }

    public let binding: KeyBinding
    public let target: Target
}
