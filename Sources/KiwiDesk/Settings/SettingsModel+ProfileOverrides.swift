import Foundation
import KiwiDeskCore

/// Stored-profile save actions and override affordances
/// (#18, #55 phase 7, #64).
extension SettingsModel {
    /// Duplicates edited stored profile as a new copy target (#82).
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

    /// Overwrites stored profile with staged configuration (#18).
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

    /// Base keybinding rows for Shortcuts override affordance (#55).
    func overrideBaseRows(layer name: String) -> [KeyBinding]? {
        guard let base = profileEditingBaseLayers else {
            return nil
        }
        return base.first { $0.name == name }?.bindings ?? []
    }

    /// Indicates whether edited profile keys diverge from base (#55 phase 7).
    var editedProfileOverridesKeys: Bool {
        guard let base = profileEditingBaseLayers else {
            return false
        }
        return KeyLayerOverride.diff(
            base: base,
            edited: config.layers
        ) != nil
    }

    /// Indicates whether edited profile app rules diverge from base (#109).
    var editedProfileOverridesAppRules: Bool {
        guard let appBase = profileEditingBaseAppRules,
            let floatBase = profileEditingBaseFloatRules
        else {
            return false
        }
        return
            AppRuleOverride.diff(
                base: appBase,
                edited: config.appRules
            ) != nil
            || RuleListOverride.diff(
                base: floatBase,
                edited: config.floatRules,
                normalizing: FloatRules.normalizedRule
            ) != nil
    }
}
