import Foundation
import KiwiDeskCore

/// The keybinding-conflict in-app warning banner — split out of
/// `SettingsModel.swift` (which owns `keybindingWarning` and the
/// rest of the model state) to stay under the file-size ceiling.
extension SettingsModel {
    /// Rows the conflict machinery may consider (#181): while
    /// advanced track is off, the gated catalog rows register
    /// no hotkey, so they must not count as conflicts either —
    /// a warning would name a row the GUI no longer renders.
    /// One filter for every GUI entry into
    /// `KeybindingConflicts`.
    func conflictRelevant(
        _ bindings: [KeyBinding]
    ) -> [KeyBinding] {
        guard !config.trackAdvanced else { return bindings }
        return bindings.filter {
            !TrackAdvancedBindings.isGated($0.lua)
        }
    }

    private func conflictRelevant(
        _ modes: [KeyMode]
    ) -> [KeyMode] {
        guard !config.trackAdvanced else { return modes }
        return modes.map { mode in
            var mode = mode
            mode.bindings = conflictRelevant(mode.bindings)
            return mode
        }
    }

    /// Whether recording over this row's combo steals it
    /// silently (#181): an inert gated row still holds its
    /// combo in the stored mode, but the Steal prompt would
    /// point at a row the GUI no longer renders.
    var isSilentlyStealable: (KeyBinding) -> Bool {
        let advanced = config.trackAdvanced
        return { binding in
            !advanced
                && TrackAdvancedBindings.isGated(binding.lua)
        }
    }

    /// The banner text, derived live: nil once dismissed —
    /// and nil once every conflict it named is fixed, however
    /// it was fixed (clearing a combo or deleting a row never
    /// passes through the recorder writers below, so the
    /// banner re-derives instead of latching stale text).
    var liveKeybindingBanner: String? {
        guard keybindingWarning != nil else { return nil }
        return Self.formatConflicts(
            KeybindingConflicts.conflicts(
                in: conflictRelevant(config.modes)
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
            in: conflictRelevant(config.modes)
        )
        if KeybindingConflicts.text(
            for: binding,
            in: conflictRelevant(bindings)
        ) != nil {
            keybindingWarning = Self.formatConflicts(list)
        } else if list.isEmpty {
            keybindingWarning = nil
        } else if keybindingWarning != nil {
            keybindingWarning = Self.formatConflicts(list)
        }
    }

    /// Sets or clears the banner from a whole-config check —
    /// used by the two batch paths (Adopt, Lua editor save)
    /// where no single recorder input triggered the check.
    /// Internal (not `private`): called from `SettingsModel`'s
    /// own `saveLuaSource()` / `adoptIntoGui()`.
    func warnIfAnyConflict() {
        let list = KeybindingConflicts.conflicts(
            in: conflictRelevant(config.modes)
        )
        keybindingWarning =
            list.isEmpty ? nil : Self.formatConflicts(list)
    }

    /// Renders a named, enumerated summary: a single sentence
    /// for one conflict, or a bulleted list for several.
    private static func formatConflicts(
        _ conflicts: [Conflict]
    ) -> String? {
        guard let only = conflicts.first else { return nil }
        guard conflicts.count > 1 else {
            return sentence(only)
        }
        let lines = conflicts.map { "– \(bulletLine($0))" }
        return L(
            "keybinding.conflict.several",
            "Several shortcuts are conflicting:\n"
        )
            + lines.joined(separator: "\n")
    }

    /// The single-conflict sentence, name and target together —
    /// one template per target kind so a translation can reorder
    /// the quoted name relative to the rest of the sentence
    /// (issue #9 review: two `+`-concatenated fragments can't be
    /// reordered by a translation).
    private static func sentence(_ conflict: Conflict) -> String {
        switch conflict.target {
        case .unrecognized:
            return L(
                "keybinding.conflict.unrecognized",
                "Shortcut for \"%1$@\" isn't a recognized "
                    + "shortcut.",
                conflict.name
            )
        case .otherBinding(let who):
            return L(
                "keybinding.conflict.other_binding",
                "Shortcut for \"%1$@\" is conflicting with "
                    + "\"%2$@\".",
                conflict.name,
                who
            )
        case .systemShortcut(let name):
            return L(
                "keybinding.conflict.system",
                "Shortcut for \"%1$@\" is conflicting with "
                    + "the macOS shortcut \"%2$@\".",
                conflict.name,
                name
            )
        }
    }

    /// One bullet line's text (no leading "– ", added by the
    /// caller).
    private static func bulletLine(_ conflict: Conflict) -> String {
        switch conflict.target {
        case .unrecognized:
            return L(
                "keybinding.conflict.bullet.unrecognized",
                "\"%1$@\" isn't a recognized shortcut",
                conflict.name
            )
        case .otherBinding(let who):
            return L(
                "keybinding.conflict.bullet.with",
                "\"%1$@\" with \"%2$@\"",
                conflict.name,
                who
            )
        case .systemShortcut(let name):
            return L(
                "keybinding.conflict.bullet.system",
                "\"%1$@\" with the macOS shortcut \"%2$@\"",
                conflict.name,
                name
            )
        }
    }
}
