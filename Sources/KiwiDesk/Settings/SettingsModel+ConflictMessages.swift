import Foundation
import KiwiDeskCore

/// Keybinding conflict warning banner formatting for SettingsModel.
extension SettingsModel {
    /// The ONE aggregate conflict read (#1094/#1105). An
    /// aggregate surface takes this — never a `KeybindingConflicts`
    /// aggregate directly, which cannot know the live enabled
    /// state; `ConflictAccessorRoutingTests` holds the family to
    /// its allow-list.
    func actionableConflicts() -> [Conflict] {
        KeybindingConflicts.actionable(
            in: config.layers,
            disabledSystemShortcuts: disabledSystemShortcuts()
        )
    }

    /// The per-shortcut half of the verdict (#1105): which
    /// register chords macOS has switched OFF right now. A row
    /// surface narrating dormancy (#1126) is handed this —
    /// never the reader or `SystemShortcutEnablement` itself.
    func disabledSystemShortcuts() -> Set<SystemShortcut> {
        SystemShortcutEnablement.disabled(
            reading: readSymbolicHotkey
        )
    }

    /// Live derived banner text reflecting active conflicts
    /// (`KeybindingConflicts`).
    var liveKeybindingBanner: String? {
        guard keybindingWarning != nil else { return nil }
        return formatConflicts(actionableConflicts())
    }

    /// Evaluates conflict state after recording a combo. An edit
    /// leaving some OTHER row conflicting only refreshes the
    /// banner if already shown — an unrelated valid edit must not
    /// newly pop it open.
    func noteRecordedCombo(
        _ binding: KeyBinding,
        in bindings: [KeyBinding]
    ) {
        let list = actionableConflicts()
        if KeybindingConflicts.conflict(
            for: binding,
            in: bindings
        ) != nil {
            keybindingWarning = formatConflicts(list)
        } else if list.isEmpty {
            keybindingWarning = nil
        } else if keybindingWarning != nil {
            keybindingWarning = formatConflicts(list)
        }
    }

    /// Updates conflict banner for whole configuration on batch operations.
    func warnIfAnyConflict() {
        let list = actionableConflicts()
        keybindingWarning =
            list.isEmpty ? nil : formatConflicts(list)
    }

    /// Localized keybinding name lookup (`KeybindingCatalog`, #96).
    private func localized(_ name: String) -> String {
        KeybindingCatalog.localizedLabel(
            for: name,
            config: config
        )
    }

    /// Formats single conflict sentence or bulleted list.
    private func formatConflicts(
        _ conflicts: [Conflict]
    ) -> String? {
        guard let only = conflicts.first else { return nil }
        guard conflicts.count > 1 else {
            return sentence(only)
        }
        let lines = conflicts.map { "– \(bulletLine($0))" }
        // The separator lives HERE, not on the translatable
        // string: it was a trailing \n inside the English, and
        // `merge-keys` trims surrounding whitespace off every
        // translation — all eleven locales shipped without it. A
        // structural newline is not copy.
        return L(
            "keybinding.conflict.several",
            "Several shortcuts are conflicting:"
        )
            + "\n"
            + lines.joined(separator: "\n")
    }

    /// Formats single conflict explanation sentence (#9).
    private func sentence(_ conflict: Conflict) -> String {
        switch conflict.target {
        case .unrecognized:
            return L(
                "keybinding.conflict.unrecognized",
                "Shortcut for \"%1$@\" isn't a recognized "
                    + "shortcut.",
                localized(conflict.name)
            )
        case .otherBinding(let who):
            return L(
                "keybinding.conflict.other_binding",
                "Shortcut for \"%1$@\" is conflicting with "
                    + "\"%2$@\".",
                localized(conflict.name),
                localized(who)
            )
        case .systemShortcut(let shortcut):
            return L(
                "keybinding.conflict.system",
                "Shortcut for \"%1$@\" is conflicting with "
                    + "the macOS shortcut \"%2$@\".",
                localized(conflict.name),
                shortcut.localizedName
            )
        }
    }

    /// Formats bullet point text for individual conflict in list.
    private func bulletLine(_ conflict: Conflict) -> String {
        switch conflict.target {
        case .unrecognized:
            return L(
                "keybinding.conflict.bullet.unrecognized",
                "\"%1$@\" isn't a recognized shortcut",
                localized(conflict.name)
            )
        case .otherBinding(let who):
            return L(
                "keybinding.conflict.bullet.with",
                "\"%1$@\" with \"%2$@\"",
                localized(conflict.name),
                localized(who)
            )
        case .systemShortcut(let shortcut):
            return L(
                "keybinding.conflict.bullet.system",
                "\"%1$@\" with the macOS shortcut \"%2$@\"",
                localized(conflict.name),
                shortcut.localizedName
            )
        }
    }
}
