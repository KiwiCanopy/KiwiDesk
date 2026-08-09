import Foundation

/// The mode pick's model half and the draft-state recompute
/// (#678 turn 9) — split from `SettingsModel.swift` for the
/// §2.1 size target.
extension SettingsModel {
    /// The one recompute for the dirty flag AND the header's
    /// per-setting count — a live comparison against the
    /// baselines, never a latch, so the two cannot disagree.
    func recomputeDirty() {
        isDirty =
            config != cleanConfig
            || luaSource != cleanLuaSource
        draftChangeCount =
            isDirty
            ? SettingsDraftDiff.between(
                config: config,
                cleanConfig: cleanConfig,
                luaSource: luaSource,
                cleanLuaSource: cleanLuaSource
            ).total
            : 0
    }

    /// Persists the pick and repairs the selection: a Power-User-only
    /// area the flip just removed pops to Home (the area ceased
    /// to exist — mode gates whole cards, so this is the
    /// settled "which cards exist" rule, not a grey-don't-hide
    /// case).
    func setSettingsMode(_ mode: SettingsMode) {
        SettingsModePreference.write(
            mode,
            to: preferences
        )
        settingsMode = mode
        if let current = destination,
            !HomeCardOrder.isOffered(
                current,
                mode: mode,
                displayCount: displays.count,
                editingStoredProfile: editingStoredProfile
            )
        {
            destination = nil
        }
    }

    /// The EXPLICIT flip — the header segment's entry point, and
    /// deliberately the only one (#760): flipping into Power
    /// User washes the surfaces the flip inserts, and the wash
    /// answers "what did the toggle just change", a question
    /// only the user's own flip asks. `ensureModeAdmits`'
    /// implicit promotion keeps calling `setSettingsMode`
    /// directly — there the user asked for a destination and the
    /// search reveal already washes it; a second wash in the
    /// same landing would dilute the one they asked for.
    ///
    /// Activation precedes the mode publish so the inserted
    /// views mount inside the same SwiftUI transaction with the
    /// wash already on. The way back to Simple never washes:
    /// leaving content is not worth pointing at (#760).
    ///
    /// `reduceMotion` comes from the caller's environment. With
    /// it on, the wash appears flat and is removed without a
    /// fade — the house split keeps the affordance and drops
    /// only the cross-fade — so the hold absorbs the fade's
    /// duration, same as the search reveal's driver.
    func flipSettingsMode(
        _ mode: SettingsMode,
        reduceMotion: Bool
    ) {
        let reveals =
            mode == .powerUser && settingsMode != .powerUser
        if reveals {
            modeRevealTask?.cancel()
            modeRevealActive = true
        } else if mode != .powerUser {
            // Flipping away ends a running wash outright — the
            // way back is a plain fade, never a highlight, and
            // a stale timeline must not clear a LATER flip's
            // wash early.
            modeRevealTask?.cancel()
            modeRevealActive = false
        }
        setSettingsMode(mode)
        guard reveals else { return }
        modeRevealTask = Task { @MainActor [weak self] in
            try? await Task.sleep(
                nanoseconds: SettingsReveal.nanoseconds(
                    SettingsReveal.hold
                        + (reduceMotion ? SettingsReveal.fade : 0)
                )
            )
            guard !Task.isCancelled else { return }
            // Clearing is what triggers the fade — the wash
            // modifier keeps no timer of its own, the same
            // one-writer shape as the search flash.
            self?.modeRevealActive = false
        }
    }
}
