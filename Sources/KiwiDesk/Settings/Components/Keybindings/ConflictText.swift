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
        KeybindingConflicts.conflict(
            for: binding,
            in: bindings,
            distinguishingSides: sides
        ).map { ConflictSeverity.of($0, disabled: disabled) }
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
                for: binding,
                in: bindings,
                disabled: disabled,
                sides: sides
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
        case .sideCollapse(let who):
            return L(
                "keybinding.conflict.tooltip.side_collapse",
                "Also bound in this layer to %1$@ on the other side. "
                    + "While left and right modifiers aren't told "
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
        case .dormant(let shortcut):
            return L(
                "keybinding.conflict.tooltip.system_off",
                "macOS reserves this shortcut for %1$@, which "
                    + "is switched off right now.",
                shortcut.localizedName
            )
        }
    }
}
