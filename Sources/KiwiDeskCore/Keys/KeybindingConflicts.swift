import Foundation

/// Conflict detection for the keybindings tab. Comparisons run
/// on the parsed `KeyCombo` (key code + modifiers), so they are
/// independent of how a combo was spelled. Lives in Core (not
/// the GUI target) since it is pure logic over
/// `KeyBinding`/`KeyLayer`, with no GUI dependency.
public enum KeybindingConflicts {
    /// Whether any row in the set carries a conflict. This is
    /// the per-layer primitive `hasAnyAcrossModes` reduces over:
    /// layers are independent keymaps, so each is checked
    /// against its own rows only, never across layers.
    public static func hasAny(_ bindings: [KeyBinding]) -> Bool {
        bindings.contains { binding in
            conflict(for: binding, in: bindings) != nil
        }
    }

    /// Whether any layer's bindings carry a conflict — drives
    /// the in-app warning shown after recording a conflicting
    /// shortcut, adopting a config, or saving from the raw Lua
    /// editor (see `SettingsModel`).
    public static func hasAnyAcrossModes(
        _ layers: [KeyLayer]
    ) -> Bool {
        layers.contains { hasAny($0.bindings) }
    }

    /// Structured conflicts across all layers, for building a
    /// named, enumerated summary (see `SettingsModel`'s banner
    /// formatter). One entry per conflicting row; a row that
    /// duplicates another and *also* shadows a system shortcut
    /// only reports the first match, since it reduces over
    /// `conflict(for:in:)` and inherits its branch order.
    public static func conflicts(
        in layers: [KeyLayer]
    ) -> [Conflict] {
        layers.flatMap { layer in
            layer.bindings.compactMap { binding in
                conflict(for: binding, in: layer.bindings)
            }
        }
    }

    /// One row's conflict: its display name and what it clashes
    /// with, or nil if the row is empty/unique/valid. **The one
    /// public per-row primitive** — the GUI renders both the row
    /// tooltip and the banner from this structure, because a
    /// pre-rendered English sentence could never be translated
    /// from actor-free Core (#96).
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
}

/// One row's conflict, as structured data (see
/// `KeybindingConflicts.conflicts(in:)`).
public struct Conflict: Equatable, Sendable {
    /// What this row clashes with.
    public enum Target: Equatable, Sendable {
        /// A reserved macOS shortcut, as a case the GUI
        /// localizes (never its English name — see
        /// `SystemShortcut`, #96).
        case systemShortcut(SystemShortcut)
        /// Another row in the same layer, by its display name.
        case otherBinding(String)
        /// The combo itself couldn't be parsed — not a "conflicts
        /// with X" case, just an invalid shortcut.
        case unrecognized
    }

    /// The conflicting action's display label, or its combo
    /// string when the row has no label (e.g. an unnamed
    /// custom binding).
    public let name: String
    public let target: Target
}
