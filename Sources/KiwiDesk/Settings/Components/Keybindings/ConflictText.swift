import KiwiDeskCore
import SwiftUI

/// A row's whole reading of its conflict: the tier that decides
/// how it is DRAWN and the sentence that says it, minted
/// together (#1126). ONE value, because two parameters let a
/// mount pass the tier without the words — a red outline saying
/// nothing, which is hue alone.
struct ConflictReading: Equatable {
    let severity: ConflictSeverity
    let sentence: String
}

/// Keybinding conflict tooltip and localized system shortcut names (#96).
enum ConflictText {
    /// The row's reading of its conflict (#1126), or nil when
    /// the row has none. `disabled` is the section's one live
    /// read (`\.disabledSystemShortcuts`), and `sides` the Mac's
    /// `modifier.sides` switch (#2601).
    static func severity(
        for binding: KeyBinding,
        in bindings: [KeyBinding],
        disabled: Set<SystemShortcut>,
        sides: Bool
    ) -> ConflictSeverity? {
        severity(
            of: KeybindingConflicts.conflict(
                for: binding,
                in: bindings,
                distinguishingSides: sides
            ),
            disabled: disabled
        )
    }

    /// The tier of a conflict already found.
    static func severity(
        of conflict: Conflict?,
        disabled: Set<SystemShortcut>
    ) -> ConflictSeverity? {
        conflict.map { ConflictSeverity.of($0, disabled: disabled) }
    }

    /// The tier and its sentence in one value — what every row
    /// surface takes.
    @MainActor
    static func reading(
        for binding: KeyBinding,
        in bindings: [KeyBinding],
        config: GuiConfig,
        disabled: Set<SystemShortcut>,
        sides: Bool
    ) -> ConflictReading? {
        guard
            let severity = severity(
                of: LayerConflictMemo.conflict(
                    for: binding,
                    in: bindings,
                    sides: sides
                ),
                disabled: disabled
            )
        else { return nil }
        return ConflictReading(
            severity: severity,
            sentence: sentence(for: severity, config: config)
        )
    }

    /// Tooltip text for a conflicting keybinding row — the
    /// COST, not just the collision (#1126; `KeybindingCatalog`,
    /// #96).
    @MainActor
    static func tooltip(
        for binding: KeyBinding,
        in bindings: [KeyBinding],
        config: GuiConfig,
        disabled: Set<SystemShortcut>,
        sides: Bool
    ) -> String? {
        reading(
            for: binding,
            in: bindings,
            config: config,
            disabled: disabled,
            sides: sides
        )?.sentence
    }

    /// What each tier says. The argument for the tiers is
    /// `docs/design-decisions.md` ▸ Shortcuts (#1126).
    @MainActor
    static func sentence(
        for severity: ConflictSeverity,
        config: GuiConfig
    ) -> String {
        switch severity {
        case .unrecognized:
            return L(
                "keybinding.conflict.tooltip.unrecognized",
                "Not a recognized shortcut."
            )
        case .duplicate(let who):
            return L(
                "keybinding.conflict.tooltip.other_binding",
                "Also bound in this layer to %1$@ — only one "
                    + "of the two will fire.",
                KeybindingCatalog.localizedName(
                    of: who,
                    config: config
                )
            )
        case .sidesTaken(let takers):
            let names = takers.map {
                KeybindingCatalog.localizedName(of: $0, config: config)
            }
            return L(
                "keybinding.conflict.tooltip.sides_taken",
                "Won't work: %1$@ and %2$@ take one side each of this "
                    + "shortcut.",
                names.first ?? "",
                names.dropFirst().first ?? ""
            )
        case .sideCollapse(let who):
            return L(
                "keybinding.conflict.tooltip.side_collapse",
                "Also bound in this layer to %1$@, which differs only "
                    + "in a modifier's side. While left and right "
                    + "modifiers aren't told "
                    + "apart, only one of the two will fire. Turn on "
                    + "%2$@ to separate them.",
                KeybindingCatalog.localizedName(
                    of: who,
                    config: config
                ),
                ModifierSidesWords.title
            )
        case .dead(let shortcut):
            return L(
                "keybinding.conflict.tooltip.system_dead",
                "Won't work: macOS answers this shortcut first, "
                    + "for %1$@.",
                shortcut.localizedName
            )
        case .shadowsApps(let shortcut):
            return L(
                "keybinding.conflict.tooltip.shadows_apps",
                "Takes %1$@ away from every app while it is "
                    + "bound here.",
                shortcut.localizedName
            )
        case .takesFromMacOS(let shortcut):
            return L(
                "keybinding.conflict.tooltip.step_system",
                "Takes %1$@ away from macOS while this sequence is open.",
                shortcut.localizedName
            )
        case .leaderTakesFromMacOS(let shortcut):
            return L(
                "keybinding.conflict.tooltip.leader_system",
                "Takes %1$@ away from macOS while it is bound here.",
                shortcut.localizedName
            )
        case .dormant(let shortcut):
            return L(
                "keybinding.conflict.tooltip.system_off",
                "Heads up: the %1$@ shortcut is switched off in "
                    + "System Settings. Turn it back on and macOS "
                    + "takes this key, so your KiwiDesk shortcut "
                    + "stops working.",
                shortcut.localizedName
            )
        }
    }
}

/// The page's layer conflicts, taken once per layer value (#2783).
/// It answers what `KeybindingConflicts.conflict(for:in:)` answers
/// (`ConflictTextMemoTests`).
@MainActor
enum LayerConflictMemo {
    private struct Taken {
        let rows: [KeyBinding]
        let sides: Bool
        let byID: [UUID: KeyBinding]
        let conflicts: [UUID: Conflict]
        let reaches: [UUID: SideReach]
    }

    private static var last: Taken?

    static func conflict(
        for binding: KeyBinding,
        in bindings: [KeyBinding],
        sides: Bool
    ) -> Conflict? {
        guard let last = taken(bindings, sides: sides, holding: binding)
        else {
            return KeybindingConflicts.conflict(
                for: binding,
                in: bindings,
                distinguishingSides: sides
            )
        }
        return last.conflicts[binding.id]
    }

    /// The row's side reach (#3256), from the same layer pass.
    static func reach(
        for binding: KeyBinding,
        in bindings: [KeyBinding],
        sides: Bool
    ) -> SideReach? {
        guard let last = taken(bindings, sides: sides, holding: binding)
        else {
            return KeybindingConflicts.sideReach(
                for: binding,
                in: bindings,
                distinguishingSides: sides
            )
        }
        return last.reaches[binding.id]
    }

    /// The layer's pass, taken anew when the layer moved; nil for a
    /// row from outside it, or an edited copy of one.
    private static func taken(
        _ bindings: [KeyBinding],
        sides: Bool,
        holding binding: KeyBinding
    ) -> Taken? {
        if last?.rows != bindings || last?.sides != sides {
            last = Taken(
                rows: bindings,
                sides: sides,
                byID: Dictionary(
                    bindings.map { ($0.id, $0) },
                    uniquingKeysWith: { first, _ in first }
                ),
                conflicts: KeybindingConflicts.rowConflicts(
                    of: bindings,
                    distinguishingSides: sides
                ),
                reaches: KeybindingConflicts.rowReaches(
                    of: bindings,
                    distinguishingSides: sides
                )
            )
        }
        guard let last, last.byID[binding.id] == binding,
            bindings.count == last.byID.count
        else { return nil }
        return last
    }
}
