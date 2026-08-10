import Foundation
import KiwiDeskCore

/// The keybinding-conflict in-app warning banner — split out of
/// `SettingsModel.swift` (which owns `keybindingWarning` and the
/// rest of the model state) to stay under the file-size ceiling.
extension SettingsModel {
    /// The banner text, derived live: nil once dismissed —
    /// and nil once every conflict it named is fixed, however
    /// it was fixed (clearing a combo or deleting a row never
    /// passes through the recorder writers below, so the
    /// banner re-derives instead of latching stale text).
    var liveKeybindingBanner: String? {
        guard keybindingWarning != nil else { return nil }
        return formatConflicts(
            KeybindingConflicts.conflicts(
                in: config.layers
            )
        )
    }

    /// Called after a `KeyRecorderField.onRecord` commits a new
    /// combo. Warns (naming every current conflict) if that row
    /// now conflicts; else clears the banner once the whole
    /// config has no conflict left, so it doesn't linger once
    /// the last one is fixed. An edit that leaves some *other*
    /// row still conflicting only refreshes the banner if it was
    /// already shown — an unrelated valid edit must not newly
    /// pop it open. The persistent per-row indicator remains the
    /// precise, always-live source of truth either way.
    func noteRecordedCombo(
        _ binding: KeyBinding,
        in bindings: [KeyBinding]
    ) {
        let list = KeybindingConflicts.conflicts(
            in: config.layers
        )
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

    /// Sets or clears the banner from a whole-config check —
    /// used by the two batch paths (Adopt, Lua editor save)
    /// where no single recorder input triggered the check.
    /// Internal (not `private`): called from `SettingsModel`'s
    /// own `saveLuaSource()` / `adoptIntoGui()`.
    func warnIfAnyConflict() {
        let list = KeybindingConflicts.conflicts(
            in: config.layers
        )
        keybindingWarning =
            list.isEmpty ? nil : formatConflicts(list)
    }

    /// The stored English canonical, narrated in the user's
    /// locale (#96) — instance methods now, because the roster
    /// lookup needs the config's spaces, layers and step.
    private func localized(_ name: String) -> String {
        KeybindingCatalog.localizedLabel(
            for: name,
            config: config
        )
    }

    /// Renders a named, enumerated summary: a single sentence
    /// for one conflict, or a bulleted list for several.
    private func formatConflicts(
        _ conflicts: [Conflict]
    ) -> String? {
        guard let only = conflicts.first else { return nil }
        guard conflicts.count > 1 else {
            return sentence(only)
        }
        let lines = conflicts.map { "– \(bulletLine($0))" }
        // The separator lives here, not on the end of the
        // translatable string. It used to be a trailing `\n` inside
        // the English, and `merge-keys` trims surrounding
        // whitespace off every translation — so all eleven locales
        // shipped without it and ran this header into the first
        // bullet. A structural newline is not copy; a catalog is
        // the wrong place to carry one.
        return L(
            "keybinding.conflict.several",
            "Several shortcuts are conflicting:"
        )
            + "\n"
            + lines.joined(separator: "\n")
    }

    /// The single-conflict sentence, name and target together —
    /// one template per target kind so a translation can reorder
    /// the quoted name relative to the rest of the sentence
    /// (issue #9 review: two `+`-concatenated fragments can't be
    /// reordered by a translation).
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

    /// One bullet line's text (no leading "– ", added by the
    /// caller).
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
