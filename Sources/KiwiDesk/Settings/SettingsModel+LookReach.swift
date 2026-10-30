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

    /// Stages `profile`'s switch; a switch back to what is stored
    /// drops the edit, so an undone pick leaves nothing unsaved.
    func setLookFollows(_ profile: String, _ follows: Bool) {
        if lookReachStored[profile] == follows {
            lookReachEdits[profile] = nil
        } else {
            lookReachEdits[profile] = follows
        }
    }

    /// The page's switch (#2820), the one writer of what it
    /// stages: the follow, the share and the draft's paint move
    /// together. `.use` paints the shared look over the draft only
    /// for a profile stored with its own, so the page shows what the
    /// Save keeps; switching back from it takes the paint off.
    func stageLookSwitch(_ profile: String, _ pick: LookSwitch) {
        restorePaintedLook()
        let stored = lookReachStored[profile]
        switch pick {
        case .own:
            setLookFollows(profile, false)
        case .make:
            lookShare = .make(profile: profile)
            setLookFollows(profile, true)
        case .use:
            if stored == false, let shared = core.sharedLook {
                lookShare = .use(profile: profile, paintBase: config.settings)
                config.settings = shared.worn(over: config.settings)
            }
            setLookFollows(profile, true)
        }
    }

    /// The switch back to what is stored, its paint taken off — the
    /// pill row's ↺.
    func revertLookSwitch(_ profile: String) {
        restorePaintedLook()
        lookShare = nil
        if let stored = lookReachStored[profile] {
            setLookFollows(profile, stored)
        } else {
            lookReachEdits[profile] = nil
        }
    }

    /// Takes a staged "Use the shared look" off the draft: its paint
    /// and the share, never the follow.
    private func restorePaintedLook() {
        if case .use(_, let base) = lookShare {
            config.settings = ShelfLook.unpicked(config.settings, to: base)
        }
        lookShare = nil
    }

    /// The profiles other than `edited` that wear the shared look,
    /// in menu order — the page's "Also used by" line.
    func sharedLookUsers(besides edited: String) -> [String] {
        profileMenuOrder.filter { $0 != edited && lookFollows[$0] == true }
    }

    /// Re-reads the stored switches and drops the picks — a reload,
    /// a Revert, a landed Save.
    func resetLookReach() {
        lookReachStored = core.lookReach()
        lookShare = nil
        lookReachEdits = [:]
    }

    /// Writes the staged switches; false where the write failed,
    /// the picks then staying unsaved with a warning.
    @discardableResult
    func saveLookReach() -> Bool {
        guard !lookReachEdits.isEmpty else { return true }
        repaintSharedLook()
        do {
            try core.saveLookReach(lookReachEdits, sharing: sharing)
            resetLookReach()
            return true
        } catch {
            profileWarning = L(
                "profiles.save_failed",
                "Saving failed: %1$@",
                Self.lookReachFailure(error)
            )
            core.onLog("look reach save failed: \(error)")
            return false
        }
    }

    /// What a failed look-switch write says after "Saving failed:".
    private static func lookReachFailure(_ error: Error) -> String {
        guard error is LookReachError else {
            return NewerFormatText.detail(error)
        }
        return L(
            "looks.reach.shared_not_written",
            "The shared look couldn't be written."
        )
    }

    /// A staged "Use the shared look" painted again, from the shared
    /// look as it is at the Save: the paint can have been taken off
    /// a leaf at a time, or the shared look moved since, and the
    /// draft's look is what the Save doors land (#2820).
    private func repaintSharedLook() {
        guard case .use = lookShare, let shared = core.sharedLook else {
            return
        }
        config.settings = shared.worn(over: config.settings)
    }

    /// The profile staged to make its look the shared one, with the
    /// look the page shows it wearing — what the Save lands.
    private var sharing: (profile: String, look: LookBody)? {
        guard case .make(let profile) = lookShare else { return nil }
        return (profile, LookBody(of: config.settings))
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
        return lookShare?.makes(profile) == true
            ? L(
                "looks.reach.diff.becomes_shared",
                "Its look becomes the shared look"
            )
            : L("looks.reach.diff.uses_shared", "Uses the shared look")
    }
}

/// A pick on the page's switch (#2820).
enum LookSwitch {
    case own
    case use
    case make
}

/// What the switch staged beyond the follow (#2820): one profile's
/// share at a time, since a page stages only its own.
enum LookShareStage {
    /// "Use the shared look", with the draft from before the shared
    /// look was painted over it.
    case use(profile: String, paintBase: TilingSettings)
    /// "Make this the shared look": the draft's look lands as the
    /// shared one at the Save.
    case make(profile: String)

    func makes(_ name: String) -> Bool {
        if case .make(let profile) = self { return profile == name }
        return false
    }
}
