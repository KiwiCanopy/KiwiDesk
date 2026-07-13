import Foundation
import KiwiDeskCore

/// The stored-profile editing surface of the dashboard model
/// (#18, #55 phase 7): the non-adopting save actions and the
/// Shortcuts tab's override-mode baseline/affordance helpers.
/// The edit-mode reload path lives in
/// `SettingsModel+EditTarget.swift` (#64).
extension SettingsModel {
    /// Save copy as… (#82): duplicates the edited stored
    /// profile under `requested` — including the pending
    /// edit-session changes — and makes the copy the new edit
    /// target. Non-adopting: the live layout, `gui.json`, and
    /// `init.lua` stay untouched.
    func saveEditedProfileCopy(named requested: String) {
        guard let source = editingProfile else { return }
        let trimmed = requested.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return }
        do {
            let created = try core.copyProfile(
                named: source,
                to: trimmed,
                with: config
            )
            // The copy is a fresh, non-active profile, so it is
            // its own stored edit target — assign it directly
            // (bypassing the discard-confirm round-trip
            // `selectEditTarget` would run) and reload onto it.
            target = .storedProfile(created)
            reload()
        } catch {
            profileWarning = L(
                "profiles.copy_failed",
                "Copying failed: %1$@",
                "\(error)"
            )
            core.onLog("profile copy failed: \(error)")
        }
    }

    /// Writes the edited tiling into the stored profile without
    /// switching the live layout, then hot-reloads it only if it
    /// is the layout currently on screen (#18).
    func saveEditedProfile() {
        guard let name = editingProfile else { return }
        do {
            try core.overwriteProfile(named: name, with: config)
        } catch {
            profileWarning = L(
                "profiles.save_failed",
                "Saving failed: %1$@",
                "\(error)"
            )
            core.onLog("profile edit save failed: \(error)")
            return
        }
        core.reapplyIfInEffect(name)
        reload()
    }

    // MARK: - Override-mode Shortcuts affordance (#55)

    /// The selected mode's base rows for the Shortcuts tab's
    /// override affordance; nil during live editing, empty
    /// when the mode only exists in the profile.
    func overrideBaseRows(mode name: String) -> [KeyBinding]? {
        guard let base = profileEditingBaseModes else {
            return nil
        }
        return base.first { $0.name == name }?.bindings ?? []
    }

    /// True while the edited profile's shortcuts diverge from
    /// the base — drives the "overrides base keybindings"
    /// indicator (#55 phase 7).
    var editedProfileOverridesKeys: Bool {
        guard let base = profileEditingBaseModes else {
            return false
        }
        return KeyModeOverride.diff(
            base: base,
            edited: config.modes
        ) != nil
    }

    /// True while the edited profile's app rules diverge from
    /// the base — drives the "overrides base app rules"
    /// indicator (#109), the shortcuts twin above.
    var editedProfileOverridesAppRules: Bool {
        guard let base = profileEditingBaseAppRules else {
            return false
        }
        return AppRuleOverride.diff(
            base: base,
            edited: config.appRules
        ) != nil
    }
}
