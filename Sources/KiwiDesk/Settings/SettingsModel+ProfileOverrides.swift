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
        // The rule half first: a failed write keeps the draft
        // whole rather than committing the tiling alone.
        // Its own shortcut override is the diff `overwriteProfile`
        // takes below, against the base written here.
        let rules = saveRuleReach()
        guard rules != .failed else {
            // A write that failed after others landed: re-read, so
            // the draft's diff shows only what did not land.
            ruleReachStored = core.ruleReachSnapshot()
            recomputeDirty()
            return
        }
        do {
            // With a checklist the rule families are the table's,
            // already written above — one encoder per field.
            try core.overwriteProfile(
                named: name,
                with: config,
                writingRules: ruleReachStored == nil
            )
        } catch {
            profileWarning = L(
                "profiles.save_failed",
                "Saving failed: %1$@",
                "\(error)"
            )
            core.onLog("profile edit save failed: \(error)")
            // A rule half that landed is the draft's clean state;
            // one that wrote nothing stays unsaved with the rest.
            if rules == .landed { adoptRuleHalf() }
            return
        }
        persistBindingsIfEdited()
        core.reapplyIfInEffect(name)
        reload()
    }

    /// The one global leaf a stored-profile draft keeps live —
    /// the Desktop binding table — leaves it by its own write,
    /// per ENTRY onto the store's map (#1392): the user owns the
    /// rows they touched, Core owns the rest (#1147).
    private func persistBindingsIfEdited() {
        let edits = bindingEdits
        guard !edits.isEmpty else { return }
        do {
            try core.rewriteSidecarBindings { edits.apply(to: &$0) }
        } catch let error as SidecarError {
            profileWarning = Self.sidecarRefusal(error)
            core.onLog("desktop bindings save refused: \(error)")
        } catch {
            profileWarning = L(
                "settings.globals_save_failed",
                "Saving settings failed: %1$@",
                "\(error)"
            )
            core.onLog("desktop bindings save failed: \(error)")
        }
    }

    /// Core names the refusal; the GUI narrates it (#96).
    private static func sidecarRefusal(_ error: SidecarError) -> String {
        switch error {
        case .missing:
            return L(
                "settings.bindings_save.no_sidecar",
                "Desktop bindings were not saved: gui.json does "
                    + "not exist yet."
            )
        case .unreadable:
            return L(
                "settings.bindings_save.unreadable",
                "Desktop bindings were not saved: gui.json could "
                    + "not be read."
            )
        }
    }
}
