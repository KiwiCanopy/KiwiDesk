import KiwiDeskCore

/// The Shared look switch's draft half (#1752, #2820): its picks
/// are staged like any edit and written by a Save through the one
/// `KiwiCore.saveLookReach`, before that Save's `gui.json` write.
extension SettingsModel {
    /// Whether each profile follows the shared look, as the page
    /// shows it: the stored switches, the draft's picks over them.
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

    /// "Use the shared look" (#2820): `profile`, this page's own,
    /// follows the shared look, and the draft wears it now so the
    /// page shows what the Save keeps.
    func useSharedLook(_ profile: String) {
        lookShare.source = nil
        if lookShare.paintBase == nil {
            lookShare.paintBase = config.settings
        }
        if let shared = core.sharedLook {
            config.settings = shared.worn(over: config.settings)
        }
        setLookFollows(profile, true)
    }

    /// "Make this the shared look" (#2820): `profile` follows, and
    /// at the Save its own look becomes the shared one first.
    func makeSharedLook(_ profile: String) {
        restorePaintedLook()
        lookShare.source = profile
        setLookFollows(profile, true)
    }

    /// "This profile only": `profile` keeps a look of its own — the
    /// one it wears now, or the draft's from before a staged "Use
    /// the shared look" painted it.
    func keepOwnLook(_ profile: String) {
        restorePaintedLook()
        if lookShare.source == profile { lookShare.source = nil }
        setLookFollows(profile, false)
    }

    /// Takes a staged "Use the shared look" paint back off the draft.
    func restorePaintedLook() {
        guard let base = lookShare.paintBase else { return }
        lookShare.paintBase = nil
        config.settings = ShelfLook.unpicked(config.settings, to: base)
    }

    /// The profiles other than `edited` that wear the shared look,
    /// in menu order — the page's "Also used by" line.
    func sharedLookUsers(besides edited: String) -> [String] {
        profileMenuOrder.filter { $0 != edited && lookFollows[$0] == true }
    }

    /// Re-reads the stored switches and drops the ticks — a reload,
    /// a Revert, a landed Save.
    func resetLookReach() {
        lookReachStored = core.lookReach()
        lookShare.source = nil
        lookShare.paintBase = nil
        lookReachEdits = [:]
    }

    /// Writes the staged ticks; false where the write failed, the
    /// ticks then staying unsaved with a warning.
    @discardableResult
    func saveLookReach() -> Bool {
        guard !lookReachEdits.isEmpty else { return true }
        do {
            try core.saveLookReach(
                lookReachEdits,
                sharing: lookShare.source
            )
            resetLookReach()
            return true
        } catch {
            profileWarning = L(
                "profiles.save_failed",
                "Saving failed: %1$@",
                NewerFormatText.detail(error)
            )
            core.onLog("look reach save failed: \(error)")
            return false
        }
    }

    /// The save pill's rows for the staged switches, one per profile
    /// whose switch a Save would change — every reason the pill
    /// shows owes a row (gui.md).
    func lookReachDiffRows() -> [SettingsDiffRow] {
        lookReachEdits.keys.sorted().compactMap { profile in
            guard let follows = lookReachEdits[profile] else {
                return nil
            }
            var row = SettingsDiffRow.note(
                .colours(.lookAppliesTo),
                instance: "look.\(profile)",
                label: profile,
                note: lookReachNote(profile, follows: follows)
            )
            row.revert = .look(profile: profile)
            return row
        }
    }

    private func lookReachNote(_ profile: String, follows: Bool) -> String {
        guard follows else {
            return L(
                "looks.reach.diff.own",
                "Keeps the look it wears as its own"
            )
        }
        return lookShare.source == profile
            ? L(
                "looks.reach.diff.becomes_shared",
                "Its look becomes the shared look"
            )
            : L("looks.reach.diff.uses_shared", "Uses the shared look")
    }
}

/// What the Shared look switch staged beyond the follow (#2820).
struct LookShareStage {
    /// The profile staged to make its own look the shared one at
    /// the Save, else nil.
    var source: String?
    /// The draft's settings before "Use the shared look" painted the
    /// shared look over them, so taking the switch back restores
    /// them; nil while nothing is painted.
    var paintBase: TilingSettings?
}
