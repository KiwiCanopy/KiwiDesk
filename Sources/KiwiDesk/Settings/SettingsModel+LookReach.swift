import KiwiDeskCore

/// The "Look applies to" checklist's draft half (#1752): its ticks
/// are staged like any edit and written by a Save through the one
/// `KiwiCore.saveLookReach`, before that Save's `gui.json` write.
extension SettingsModel {
    /// Whether each profile follows the shared look, as the
    /// checklist shows it: the stored switches, the draft's ticks
    /// over them.
    var lookFollows: [String: Bool] {
        lookReachStored.merging(lookReachEdits) { $1 }
    }

    /// Stages `profile`'s tick; a tick back to what is stored
    /// drops the edit, so an undone tick leaves nothing unsaved.
    func setLookFollows(_ profile: String, _ follows: Bool) {
        if lookReachStored[profile] == follows {
            lookReachEdits[profile] = nil
        } else {
            lookReachEdits[profile] = follows
        }
    }

    /// "All profiles": every profile follows the shared look.
    func setLookFollowsAll() {
        for name in lookReachStored.keys { setLookFollows(name, true) }
    }

    /// Re-reads the stored switches and drops the ticks — a reload,
    /// a Revert, a landed Save.
    func resetLookReach() {
        lookReachStored = core.lookReach()
        lookReachEdits = [:]
    }

    /// Writes the staged ticks; false where the write failed, the
    /// ticks then staying unsaved with a warning.
    @discardableResult
    func saveLookReach() -> Bool {
        guard !lookReachEdits.isEmpty else { return true }
        do {
            try core.saveLookReach(lookReachEdits)
            resetLookReach()
            return true
        } catch {
            profileWarning = L(
                "profiles.save_failed",
                "Saving failed: %1$@",
                "\(error)"
            )
            core.onLog("look reach save failed: \(error)")
            return false
        }
    }

    /// The save pill's rows for the staged ticks, one per profile
    /// whose switch a Save would change — every reason the pill
    /// shows owes a row (gui.md).
    func lookReachDiffRows() -> [SettingsDiffRow] {
        lookReachEdits.keys.sorted().compactMap { profile in
            guard let follows = lookReachEdits[profile] else {
                return nil
            }
            return .note(
                .colours(.lookAppliesTo),
                instance: "look.\(profile)",
                label: profile,
                note: follows
                    ? L(
                        "looks.reach.diff.shared",
                        "Uses the shared look"
                    )
                    : L("looks.reach.diff.own", "Gets its own look")
            )
        }
    }
}
